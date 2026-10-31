import { PersonalRemindersService } from '../personal-reminders.service';

function setup(row: any, caregiver: any = { id: 'carer', languagePreference: 'EN', memberName: 'Amina' }) {
  const prisma: any = {
    personalReminder: {
      findUnique: jest.fn(async () => row),
      create: jest.fn(async ({ data }: any) => ({ id: 'p1', active: true, ...data })),
    },
  };
  prisma.$transaction = async (fn: any) => fn(prisma);
  const notifications: any = { notify: jest.fn() };
  const caregivers: any = { notifyMember: jest.fn(), caregiverOf: jest.fn(async () => caregiver) };
  const service = new PersonalRemindersService(prisma, { record: jest.fn() } as any, notifications, caregivers);
  return { service, prisma, notifications, caregivers };
}

const base = { id: 'p1', userId: 'u1', active: true, scheduleTimes: '["08:00"]', intervalDays: 1 };

describe('PersonalRemindersService', () => {
  it('Later on a reminder the caregiver set up tells the caregiver, once per ring', async () => {
    const { service, notifications } = setup({ ...base, createdById: 'carer' });
    expect(await service.later('u1', 'p1', '2026-11-01T02:00:00.000Z')).toEqual({ notified: true });
    const [[rows]] = notifications.notify.mock.calls;
    expect(rows[0]).toMatchObject({
      userId: 'carer',
      relatedEntityId: 'prlater:p1:2026-11-01T02:00:00.000Z',
      data: { kind: 'personal_reminder_later', memberUserId: 'u1' },
    });
  });

  it('Later on my own reminder tells nobody', async () => {
    const { service, notifications } = setup({ ...base, createdById: 'u1' });
    expect(await service.later('u1', 'p1')).toEqual({ notified: false });
    expect(notifications.notify).not.toHaveBeenCalled();
  });

  it("someone else's reminder is a 404", async () => {
    const { service } = setup({ ...base, userId: 'other', createdById: 'other' });
    await expect(service.later('u1', 'p1')).rejects.toThrow('Reminder not found');
  });

  it('a caregiver creating one for a member: stored for the member, flagged, member told', async () => {
    const { service, prisma, caregivers } = setup(null);
    const r = await service.create(
      { actorId: 'carer', subjectId: 'u1', byCaregiver: true },
      { name: 'Walk', description: '30 minutes', scheduleTimes: ['07:00', '18:00'], intervalDays: 2 },
    );
    expect(prisma.personalReminder.create.mock.calls[0][0].data).toMatchObject({
      userId: 'u1',
      createdById: 'carer',
      scheduleTimes: '["07:00","18:00"]',
      intervalDays: 2,
    });
    expect(r.byCaregiver).toBe(true);
    expect(caregivers.notifyMember).toHaveBeenCalledWith(expect.anything(), 'reminder_added', 'p1');
  });
});
