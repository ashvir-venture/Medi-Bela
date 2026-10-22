import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { PrescriptionStatus, Role } from '@prisma/client';
import { PrescriptionsService } from '../prescriptions.service';
import { RoutineGenerationService } from '../lib/routine-generation.service';

/** Minimal in-memory fake standing in for PrismaService, scoped to what
 * PrescriptionsService touches. Keeps these tests fast and DB-free while
 * still exercising the real transition/validation logic. */
function makeFakePrisma() {
  const prescriptions = new Map<string, any>();
  const medicines = new Map<string, any>();
  const routines: any[] = [];
  const doses: any[] = [];

  return {
    _state: { prescriptions, medicines, routines, doses },
    prescription: {
      findUnique: jest.fn(async ({ where, include }: any) => {
        if (where.id) {
          const p = prescriptions.get(where.id);
          if (!p) return null;
          // Emulate `include: { medicines }` which complete() relies on.
          return include?.medicines
            ? { ...p, medicines: [...medicines.values()].filter((m) => m.prescriptionId === p.id) }
            : p;
        }
        if (where.clientUploadId) {
          return (
            [...prescriptions.values()].find((p) => p.clientUploadId === where.clientUploadId) ??
            null
          );
        }
        return null;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `presc-${prescriptions.size + 1}`;
        const record = {
          id,
          status: PrescriptionStatus.PENDING,
          createdAt: new Date(),
          updatedAt: new Date(),
          ...data,
        };
        prescriptions.set(id, record);
        return record;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const record = prescriptions.get(where.id);
        Object.assign(record, data);
        return record;
      }),
      // Compare-and-set used by complete()/reject(): only matches while PENDING.
      updateMany: jest.fn(async ({ where, data }: any) => {
        const record = prescriptions.get(where.id);
        if (!record || (where.status && record.status !== where.status)) return { count: 0 };
        Object.assign(record, data);
        return { count: 1 };
      }),
      findMany: jest.fn(async () => [...prescriptions.values()]),
    },
    user: {
      findUnique: jest.fn(async () => ({ languagePreference: 'EN' })),
    },
    prescriptionMedicine: {
      findMany: jest.fn(async ({ where }: any) =>
        [...medicines.values()].filter((m) => m.prescriptionId === where.prescriptionId),
      ),
      create: jest.fn(async ({ data }: any) => {
        const id = `med-${medicines.size + 1}`;
        const record = { id, createdAt: new Date(), updatedAt: new Date(), ...data };
        medicines.set(id, record);
        return record;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const record = medicines.get(where.id);
        Object.assign(record, data);
        return record;
      }),
      findUnique: jest.fn(async ({ where }: any) => medicines.get(where.id) ?? null),
      delete: jest.fn(async ({ where }: any) => {
        medicines.delete(where.id);
      }),
    },
    medicineRoutine: {
      create: jest.fn(async ({ data }: any) => {
        const id = `routine-${routines.length + 1}`;
        const record = { id, ...data };
        routines.push(record);
        return record;
      }),
    },
    medicineDose: {
      createMany: jest.fn(async ({ data }: any) => {
        doses.push(...data);
        return { count: data.length };
      }),
    },
    $transaction: jest.fn(async (arg: any) => {
      if (Array.isArray(arg)) return Promise.all(arg);
      return arg({
        prescription: (this as any).prescription,
        medicineRoutine: (this as any).medicineRoutine,
        medicineDose: (this as any).medicineDose,
      });
    }),
  } as any;
}

describe('PrescriptionsService', () => {
  let prisma: any;
  let service: PrescriptionsService;
  let fakeRuleEvaluation: { evaluateForMedicine: jest.Mock };
  let fakeNotifications: { notify: jest.Mock };

  beforeEach(() => {
    prisma = makeFakePrisma();
    // $transaction's callback form needs access to the same mocked
    // delegates as `prisma` itself (simulating Prisma's `tx` client).
    prisma.$transaction = jest.fn(async (arg: any) => {
      if (Array.isArray(arg)) return Promise.all(arg);
      return arg(prisma);
    });
    fakeRuleEvaluation = { evaluateForMedicine: jest.fn().mockResolvedValue(undefined) };
    fakeNotifications = { notify: jest.fn().mockResolvedValue(undefined) };
    service = new PrescriptionsService(
      prisma,
      new RoutineGenerationService(),
      fakeRuleEvaluation as any,
      { uploadPrescriptionImage: jest.fn(async (_b: Buffer, name: string) => `https://img.test/${name}`) } as any,
      fakeNotifications as any,
    );
  });

  describe('create (upload)', () => {
    it('creates a new prescription with PENDING status', async () => {
      const result = await service.create('user-1', Buffer.from('img'), 'photo.jpg', 'client-abc');
      expect(result.status).toBe(PrescriptionStatus.PENDING);
      expect(result.userId).toBe('user-1');
      expect(result.imageUrl).toContain('photo.jpg');
    });

    it('is idempotent: retrying the same clientId returns the existing prescription', async () => {
      const first = await service.create('user-1', Buffer.from('img'), 'photo.jpg', 'client-abc');
      const second = await service.create('user-1', Buffer.from('img'), 'photo.jpg', 'client-abc');
      expect(second.id).toBe(first.id);
      expect(prisma.prescription.create).toHaveBeenCalledTimes(1);
    });
  });

  describe('medicine entry + completion', () => {
    async function pendingPrescriptionWithMedicine() {
      const prescription = await service.create('user-1', Buffer.from('img'), 'p.jpg');
      await service.saveMedicines('admin-1', prescription.id, {
        medicines: [
          {
            medicineName: 'Amoxicillin',
            dosage: '250mg',
            frequency: 'three times daily',
            duration: '7 days',
            timesPerDay: 3,
            scheduleTimes: ['08:00', '14:00', '20:00'],
            durationDays: 7,
          } as any,
        ],
      });
      return prescription;
    }

    it('rejects completion when medicine schedule data is incomplete', async () => {
      const prescription = await service.create('user-1', Buffer.from('img'), 'p.jpg');
      await service.saveMedicines('admin-1', prescription.id, {
        medicines: [
          { medicineName: 'X', dosage: '1', frequency: 'daily', duration: '5 days' } as any,
        ],
      });
      await expect(service.complete('admin-1', prescription.id)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('completes a prescription and generates a deterministic routine', async () => {
      const prescription = await pendingPrescriptionWithMedicine();
      const result = await service.complete('admin-1', prescription.id);
      expect(result.status).toBe(PrescriptionStatus.COMPLETED);
      expect(prisma._state.routines).toHaveLength(1);
      expect(prisma._state.doses).toHaveLength(21); // 3/day * 7 days
      expect(fakeRuleEvaluation.evaluateForMedicine).toHaveBeenCalledTimes(1);
    });

    it('notifies the owner once on completion, without medicine detail in the text', async () => {
      const prescription = await pendingPrescriptionWithMedicine();
      await service.complete('admin-1', prescription.id);
      expect(fakeNotifications.notify).toHaveBeenCalledTimes(1);
      const [[items]] = fakeNotifications.notify.mock.calls;
      expect(items).toHaveLength(1);
      expect(items[0]).toMatchObject({ userId: 'user-1', type: 'PRESCRIPTION_UPDATE', relatedEntityId: prescription.id });
      expect(JSON.stringify(items[0])).not.toMatch(/Amoxicillin|250mg/);
    });

    it('does not notify or re-generate routines when completion loses the race', async () => {
      const prescription = await pendingPrescriptionWithMedicine();
      await service.complete('admin-1', prescription.id);
      fakeNotifications.notify.mockClear();
      await expect(service.complete('admin-1', prescription.id)).rejects.toThrow(ConflictException);
      expect(fakeNotifications.notify).not.toHaveBeenCalled();
      expect(prisma._state.routines).toHaveLength(1);
    });

    it('rejects a duplicate completion attempt', async () => {
      const prescription = await pendingPrescriptionWithMedicine();
      await service.complete('admin-1', prescription.id);
      await expect(service.complete('admin-1', prescription.id)).rejects.toThrow(
        ConflictException,
      );
    });

    it('rejects completion of a prescription with no medicines', async () => {
      const prescription = await service.create('user-1', Buffer.from('img'), 'p.jpg');
      await expect(service.complete('admin-1', prescription.id)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('reject', () => {
    it('rejects a pending prescription with a reason', async () => {
      const prescription = await service.create('user-1', Buffer.from('img'), 'p.jpg');
      const result = await service.reject('admin-1', prescription.id, 'Illegible image');
      expect(result.status).toBe(PrescriptionStatus.REJECTED);
      expect(result.rejectionReason).toBe('Illegible image');
    });

    it('notifies the owner on rejection WITHOUT leaking the rejection reason', async () => {
      const prescription = await service.create('user-1', Buffer.from('img'), 'p.jpg');
      await service.reject('admin-1', prescription.id, 'Illegible image');
      const [[items]] = fakeNotifications.notify.mock.calls;
      expect(items[0].type).toBe('PRESCRIPTION_UPDATE');
      expect(JSON.stringify(items[0])).not.toMatch(/Illegible/);
    });

    it('cannot reject an already-completed prescription', async () => {
      const prescription = await service.create('user-1', Buffer.from('img'), 'p.jpg');
      await service.saveMedicines('admin-1', prescription.id, {
        medicines: [
          {
            medicineName: 'X',
            dosage: '1',
            frequency: 'daily',
            duration: '1 day',
            timesPerDay: 1,
            scheduleTimes: ['08:00'],
            durationDays: 1,
          } as any,
        ],
      });
      await service.complete('admin-1', prescription.id);
      await expect(
        service.reject('admin-1', prescription.id, 'too late'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('access control at the data layer', () => {
    it('throws NotFoundException when a user requests another user\'s prescription', async () => {
      const prescription = await service.create('user-1', Buffer.from('img'), 'p.jpg');
      await expect(
        service.getMyPrescriptionDetail('someone-else', prescription.id),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
