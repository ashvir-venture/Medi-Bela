import { HealthReminderStatus, NotificationType } from '@prisma/client';
import { TestReminderJob, testCaregiverAlertAfterMs } from '../test-reminder.job';

const NOW = new Date('2026-10-31T06:00:00.000Z');

function setup(opts: { visible?: boolean; caregiver?: { id: string } | null } = {}) {
  const reminder = {
    id: 'hr-1',
    userId: 'patient',
    user: {
      name: 'Rahim',
      accountStatus: 'ACTIVE',
      profileVisibleToFamily: opts.visible ?? true,
      medicineRemindersEnabled: true,
    },
  };
  const tx: any = { healthReminder: { updateMany: jest.fn(async (_args: any) => ({ count: 1 })) } };
  const prisma: any = {
    healthReminder: {
      updateMany: jest.fn(async () => ({ count: 0 })),
      findMany: jest.fn().mockResolvedValueOnce([reminder]).mockResolvedValue([]),
    },
    familyMember: {
      findUnique: jest.fn(async () => ({ familyId: 'fam' })),
      findFirst: jest.fn(async () =>
        opts.caregiver === null ? null : { user: { id: opts.caregiver?.id ?? 'carer', languagePreference: 'EN' } },
      ),
    },
    $transaction: async (fn: any) => fn(tx),
  };
  const notifications: any = {
    createMany: jest.fn(async (rows: any[]) => rows.map((_, i) => `n${i}`)),
    dispatch: jest.fn(async () => undefined),
  };
  return { job: new TestReminderJob(prisma, notifications), prisma, tx, notifications };
}

describe('TestReminderJob', () => {
  it('on day 3 tells the caregiver, neutrally (name, no test), and claims the reminder once', async () => {
    const { job, prisma, tx, notifications } = setup();
    const result = await job.run(NOW);
    expect(result.alerted).toBe(1);
    const query = prisma.healthReminder.findMany.mock.calls[0][0];
    expect(query.where.scheduledAt.lte).toEqual(new Date(NOW.getTime() - testCaregiverAlertAfterMs()));
    expect(query.where.testId).toEqual({ not: null });
    expect(tx.healthReminder.updateMany.mock.calls[0][0].where).toMatchObject({ id: 'hr-1', caregiverAlertedAt: null });
    const [rows] = notifications.createMany.mock.calls[0];
    expect(rows[0]).toMatchObject({
      userId: 'carer',
      type: NotificationType.MISSED_DOSE_FAMILY_ALERT,
      relatedEntityId: 'test:hr-1',
      data: { memberUserId: 'patient', kind: 'test_pending' },
    });
    expect(rows[0].body).toContain('Rahim');
  });

  it('only the caregiver role, never the patient themself', async () => {
    const { job, prisma } = setup();
    await job.run(NOW);
    expect(prisma.familyMember.findFirst.mock.calls[0][0].where).toMatchObject({
      role: 'CAREGIVER',
      userId: { not: 'patient' },
    });
  });

  it('hidden from family: claimed, nobody told', async () => {
    const { job, tx, notifications } = setup({ visible: false });
    expect((await job.run(NOW)).alerted).toBe(0);
    expect(tx.healthReminder.updateMany).toHaveBeenCalled();
    expect(notifications.createMany).not.toHaveBeenCalled();
  });

  it('closes test reminders still pending a day after the third ring as MISSED', async () => {
    const { job, prisma } = setup({ caregiver: null });
    await job.run(NOW);
    const call = prisma.healthReminder.updateMany.mock.calls[0][0];
    expect(call.data).toEqual({ status: HealthReminderStatus.MISSED });
    expect(call.where.scheduledAt.lte).toEqual(new Date(NOW.getTime() - 3 * 24 * 60 * 60_000));
  });
});
