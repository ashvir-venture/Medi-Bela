import { MedicineBoxService } from '../medicine-box.service';

const countedAt = new Date('2026-10-30T00:00:00.000Z');

function setup(opts: { caregiver?: any } = {}) {
  const prisma: any = {
    user: { findUnique: jest.fn(async () => ({ medicineBoxStartedAt: countedAt })), updateMany: jest.fn() },
    medicineRoutine: {
      findMany: jest.fn(async () => [
        {
          id: 'r1',
          medicineName: 'Napa',
          dosage: '500 mg, 2 tablets',
          doseAmount: '2 tablets',
          form: { name: 'Tablet' },
          stock: { quantity: 10, countedAt },
        },
        { id: 'r2', medicineName: 'Seclo', dosage: '20 mg', doseAmount: null, form: null, stock: null },
      ]),
      count: jest.fn(async () => 1),
    },
    medicineDose: { count: jest.fn(async () => 3) },
    medicineStock: {
      upsert: jest.fn(),
      findUnique: jest.fn(async () => ({ userId: 'u1', routineId: 'r1', countedAt })),
    },
  };
  prisma.$transaction = async (fn: any) => fn(prisma);
  const notifications: any = { notify: jest.fn() };
  const caregivers: any = {
    notifyMember: jest.fn(),
    caregiverOf: jest.fn(async () => opts.caregiver ?? null),
  };
  const service = new MedicineBoxService(prisma, { record: jest.fn() } as any, notifications, caregivers);
  return { service, prisma, notifications, caregivers };
}

describe('MedicineBoxService', () => {
  it('left = counted - units of doses taken since the count; uncounted ones say so', async () => {
    const { service, prisma } = setup();
    const box = await service.get('u1');
    expect(prisma.medicineDose.count.mock.calls[0][0].where).toMatchObject({
      routineId: 'r1',
      status: 'TAKEN',
      takenAt: { gte: countedAt },
    });
    expect(box.items[0]).toMatchObject({ routineId: 'r1', unitsPerDose: 2, remaining: 4, dosesLeft: 2, formName: 'Tablet' });
    expect(box.items[1]).toMatchObject({ routineId: 'r2', quantity: null, remaining: null });
  });

  it("Refill replaces the count from now, only for the member's own active medicines", async () => {
    const { service, prisma } = setup();
    prisma.medicineRoutine.count.mockResolvedValueOnce(0);
    await expect(
      service.save({ actorId: 'u1', subjectId: 'u1', byCaregiver: false }, { items: [{ routineId: 'r9', quantity: 5 }] }),
    ).rejects.toThrow('Medicine not found');

    await service.save({ actorId: 'carer', subjectId: 'u1', byCaregiver: true }, { items: [{ routineId: 'r1', quantity: 20 }] });
    expect(prisma.medicineStock.upsert.mock.calls[0][0].update).toMatchObject({ quantity: 20, updatedById: 'carer' });
  });

  it("Ignore tells the caregiver once per count, with the member's name and no medicine", async () => {
    const { service, notifications } = setup({ caregiver: { id: 'carer', languagePreference: 'EN', memberName: 'Amina' } });
    expect(await service.ignore('u1', 'r1')).toEqual({ notified: true });
    const [[rows]] = notifications.notify.mock.calls;
    expect(rows[0]).toMatchObject({ userId: 'carer', relatedEntityId: 'stock:r1:' + countedAt.getTime() });
    expect(rows[0].body).toContain('Amina');
    expect(rows[0].body).not.toContain('Napa');
  });

  it('no caregiver: nobody is told, no error', async () => {
    const { service, notifications } = setup();
    expect(await service.ignore('u1', 'r1')).toEqual({ notified: false });
    expect(notifications.notify).not.toHaveBeenCalled();
  });
});
