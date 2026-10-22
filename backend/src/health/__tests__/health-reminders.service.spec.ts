import { NotFoundException } from '@nestjs/common';
import { HealthReminderStatus } from '@prisma/client';
import { HealthRemindersService } from '../health-reminders.service';

function makeFakePrisma() {
  const reminders = new Map<string, any>();
  return {
    _reminders: reminders,
    healthReminder: {
      findMany: jest.fn(async ({ where }: any) =>
        [...reminders.values()].filter((r) => {
          if (r.userId !== where.userId) return false;
          if (where.status && r.status !== where.status) return false;
          if (where.scheduledAt?.gt && !(r.scheduledAt > where.scheduledAt.gt)) return false;
          if (where.scheduledAt?.lte && !(r.scheduledAt <= where.scheduledAt.lte)) return false;
          return true;
        }),
      ),
      findUnique: jest.fn(async ({ where }: any) => reminders.get(where.id) ?? null),
      update: jest.fn(async ({ where, data }: any) => {
        const r = reminders.get(where.id);
        Object.assign(r, data);
        return r;
      }),
    },
  } as any;
}

function makeReminder(overrides: Partial<any> = {}) {
  return {
    id: 'reminder-1',
    userId: 'user-1',
    sourceRuleId: 'rule-1',
    title: 'Blood sugar check',
    description: 'Suggested...',
    scheduledAt: new Date(),
    status: HealthReminderStatus.PENDING,
    completedAt: null,
    ...overrides,
  };
}

describe('HealthRemindersService', () => {
  let prisma: any;
  let service: HealthRemindersService;

  beforeEach(() => {
    prisma = makeFakePrisma();
    service = new HealthRemindersService(prisma);
  });

  it('splits reminders into due (past/now) vs upcoming (future)', async () => {
    const past = makeReminder({ id: 'r1', scheduledAt: new Date(Date.now() - 60_000) });
    const future = makeReminder({ id: 'r2', scheduledAt: new Date(Date.now() + 60_000) });
    prisma._reminders.set('r1', past);
    prisma._reminders.set('r2', future);

    expect((await service.getDue('user-1')).map((r) => r.id)).toEqual(['r1']);
    expect((await service.getUpcoming('user-1')).map((r) => r.id)).toEqual(['r2']);
  });

  it('excludes completed reminders from due/upcoming', async () => {
    prisma._reminders.set(
      'r1',
      makeReminder({ id: 'r1', status: HealthReminderStatus.COMPLETED, scheduledAt: new Date(Date.now() - 1000) }),
    );
    expect(await service.getDue('user-1')).toHaveLength(0);
  });

  it('marks a reminder complete with an explicit completedAt', async () => {
    prisma._reminders.set('reminder-1', makeReminder());
    const result = await service.markComplete('user-1', 'reminder-1', '2026-03-01T00:00:00.000Z');
    expect(result.status).toBe(HealthReminderStatus.COMPLETED);
    expect(result.completedAt).toEqual(new Date('2026-03-01T00:00:00.000Z'));
  });

  it('is idempotent: completing an already-completed reminder is a no-op', async () => {
    const completedAt = new Date('2026-01-01T00:00:00.000Z');
    prisma._reminders.set(
      'reminder-1',
      makeReminder({ status: HealthReminderStatus.COMPLETED, completedAt }),
    );
    const result = await service.markComplete('user-1', 'reminder-1', '2026-06-01T00:00:00.000Z');
    expect(result.completedAt).toEqual(completedAt);
    expect(prisma.healthReminder.update).not.toHaveBeenCalled();
  });

  it("throws NotFoundException for another user's reminder", async () => {
    prisma._reminders.set('reminder-1', makeReminder({ userId: 'someone-else' }));
    await expect(service.getDetail('user-1', 'reminder-1')).rejects.toThrow(NotFoundException);
    await expect(service.markComplete('user-1', 'reminder-1')).rejects.toThrow(NotFoundException);
  });
});
