import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { DoseStatus } from '@prisma/client';
import { MedicineScheduleService } from '../medicine-schedule.service';

function makeFakePrisma() {
  const doses = new Map<string, any>();

  return {
    _doses: doses,
    medicineDose: {
      findUnique: jest.fn(async ({ where }: any) => doses.get(where.id) ?? null),
      findMany: jest.fn(async ({ where }: any) => {
        return [...doses.values()].filter((d) => {
          if (where.userId && d.userId !== where.userId) return false;
          if (where.scheduledAt?.gte && d.scheduledAt < where.scheduledAt.gte) return false;
          if (where.scheduledAt?.lt && d.scheduledAt >= where.scheduledAt.lt) return false;
          if (where.scheduledAt?.lte && d.scheduledAt > where.scheduledAt.lte) return false;
          return true;
        });
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const dose = doses.get(where.id);
        Object.assign(dose, data);
        return dose;
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        let count = 0;
        for (const d of doses.values()) {
          if (
            d.userId === where.userId &&
            d.status === where.status &&
            d.scheduledAt < where.scheduledAt.lt
          ) {
            Object.assign(d, data);
            count++;
          }
        }
        return { count };
      }),
    },
    medicineRoutine: {
      findMany: jest.fn(async () => []),
      findFirst: jest.fn(async () => null),
    },
  } as any;
}

function makeDose(overrides: Partial<any> = {}) {
  return {
    id: 'dose-1',
    routineId: 'routine-1',
    userId: 'user-1',
    scheduledAt: new Date('2026-03-01T08:00:00.000Z'),
    status: DoseStatus.PENDING,
    takenAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

describe('MedicineScheduleService — dose tracking', () => {
  let prisma: any;
  let service: MedicineScheduleService;

  beforeEach(() => {
    prisma = makeFakePrisma();
    service = new MedicineScheduleService(prisma);
  });

  describe('markDoseTaken', () => {
    it('marks a PENDING dose TAKEN with the given takenAt', async () => {
      prisma._doses.set('dose-1', makeDose());
      const result = await service.markDoseTaken('user-1', 'dose-1', '2026-03-01T08:05:00.000Z');
      expect(result.status).toBe(DoseStatus.TAKEN);
      expect(result.takenAt).toEqual(new Date('2026-03-01T08:05:00.000Z'));
    });

    it('defaults takenAt to now when not provided', async () => {
      prisma._doses.set('dose-1', makeDose());
      const before = Date.now();
      const result = await service.markDoseTaken('user-1', 'dose-1');
      expect(result.takenAt.getTime()).toBeGreaterThanOrEqual(before);
    });

    it('is idempotent: marking an already-TAKEN dose again returns the same result without changing it', async () => {
      const firstTakenAt = new Date('2026-03-01T08:05:00.000Z');
      prisma._doses.set('dose-1', makeDose({ status: DoseStatus.TAKEN, takenAt: firstTakenAt }));

      const result = await service.markDoseTaken('user-1', 'dose-1', '2026-03-01T09:00:00.000Z');

      expect(result.takenAt).toEqual(firstTakenAt); // unchanged — first write wins
      expect(prisma.medicineDose.update).not.toHaveBeenCalled();
    });

    it('allows confirming TAKEN after the system auto-marked a dose MISSED', async () => {
      prisma._doses.set('dose-1', makeDose({ status: DoseStatus.MISSED }));
      const result = await service.markDoseTaken('user-1', 'dose-1');
      expect(result.status).toBe(DoseStatus.TAKEN);
    });

    it('refuses to mark a SKIPPED dose as taken', async () => {
      prisma._doses.set('dose-1', makeDose({ status: DoseStatus.SKIPPED }));
      await expect(service.markDoseTaken('user-1', 'dose-1')).rejects.toThrow(ForbiddenException);
    });

    it('throws NotFoundException for a nonexistent dose', async () => {
      await expect(service.markDoseTaken('user-1', 'missing')).rejects.toThrow(NotFoundException);
    });

    it("throws NotFoundException (not Forbidden) when marking someone else's dose", async () => {
      prisma._doses.set('dose-1', makeDose({ userId: 'someone-else' }));
      await expect(service.markDoseTaken('user-1', 'dose-1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('missed-dose sweep', () => {
    it('converts a long-overdue PENDING dose to MISSED when read', async () => {
      const longOverdue = new Date(Date.now() - 5 * 60 * 60 * 1000); // 5h ago > default 2h grace
      prisma._doses.set('dose-1', makeDose({ scheduledAt: longOverdue, status: DoseStatus.PENDING }));

      const detail = await service.getDoseDetail('user-1', 'dose-1');

      expect(detail.status).toBe(DoseStatus.MISSED);
      expect(detail.displayStatus).toBe('MISSED');
    });

    it('does not touch a recently-due PENDING dose still inside the grace window', async () => {
      const recentlyDue = new Date(Date.now() - 10 * 60 * 1000); // 10 min ago
      prisma._doses.set('dose-1', makeDose({ scheduledAt: recentlyDue, status: DoseStatus.PENDING }));

      const detail = await service.getDoseDetail('user-1', 'dose-1');

      expect(detail.status).toBe(DoseStatus.PENDING);
      expect(detail.displayStatus).toBe('DUE');
    });

    it('never touches an already-TAKEN dose even if long overdue', async () => {
      const longOverdue = new Date(Date.now() - 5 * 60 * 60 * 1000);
      prisma._doses.set(
        'dose-1',
        makeDose({ scheduledAt: longOverdue, status: DoseStatus.TAKEN, takenAt: longOverdue }),
      );

      const detail = await service.getDoseDetail('user-1', 'dose-1');

      expect(detail.status).toBe(DoseStatus.TAKEN);
    });
  });

  describe('ownership', () => {
    it('throws NotFoundException fetching a dose belonging to another user', async () => {
      prisma._doses.set('dose-1', makeDose({ userId: 'someone-else' }));
      await expect(service.getDoseDetail('user-1', 'dose-1')).rejects.toThrow(NotFoundException);
    });
  });
});
