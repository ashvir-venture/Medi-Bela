import { RoutineManagementService } from '../routine-management.service';

/** Round 18 "Took one now" for an as-needed medicine (max 2 a day, 6 h gap). */
function setup(existing: Date[] = []) {
  const doses: any[] = existing.map((t, i) => ({ id: `d${i}`, routineId: 'r1', scheduledAt: t, takenAt: t, status: 'TAKEN' }));
  const routine = { id: 'r1', userId: 'u1', active: true, asNeeded: true, maxPerDay: 2, minGapHours: 6 };
  const prisma: any = {
    medicineRoutine: { findUnique: jest.fn(async () => routine) },
    medicineDose: {
      findFirst: jest.fn(async ({ where }: any) => doses.find((d) => d.scheduledAt.getTime() === where.scheduledAt.getTime()) ?? null),
      create: jest.fn(async ({ data }: any) => {
        const d = { id: `d${doses.length}`, ...data };
        doses.push(d);
        return d;
      }),
      findMany: jest.fn(async ({ where }: any) =>
        doses
          .filter((d) => d.scheduledAt >= where.scheduledAt.gte && d.scheduledAt < where.scheduledAt.lt)
          .sort((a, b) => a.scheduledAt - b.scheduledAt),
      ),
    },
  };
  prisma.$transaction = async (fn: any) => fn(prisma);
  const audit = { record: jest.fn() };
  const caregivers: any = {
    notifyMember: jest.fn(),
    caregiverOf: jest.fn(async () => ({ id: 'c1', languagePreference: 'EN', memberName: 'Abba' })),
  };
  const notifications: any = { notify: jest.fn() };
  const service = new RoutineManagementService(prisma, audit as any, {} as any, caregivers, notifications);
  return { service, doses, notifications, caregivers, audit };
}

const me = { actorId: 'u1', subjectId: 'u1', byCaregiver: false };
const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000);

describe('as-needed medicine: Took one now (Round 18)', () => {
  it('logs a TAKEN dose at the tap time, no warnings inside the limits', async () => {
    const s = setup();
    const r = await s.service.takeAsNeeded(me, 'r1', hoursAgo(0.1).toISOString());
    expect(r).toMatchObject({ overMax: false, tooSoon: false });
    expect(r.takenToday).toHaveLength(1);
    expect(s.doses[0]).toMatchObject({ status: 'TAKEN', userId: 'u1', takenById: null });
    expect(s.notifications.notify).not.toHaveBeenCalled();
  });

  it('too soon after the last one warns but still logs', async () => {
    const s = setup([hoursAgo(1)]);
    const r = await s.service.takeAsNeeded(me, 'r1');
    expect(r.tooSoon).toBe(true);
    expect(s.doses).toHaveLength(2);
  });

  it('over the daily most: logs, warns, and tells the caregiver once (neutral text)', async () => {
    // Two in the last few seconds: same app day whatever the clock says.
    const s = setup([new Date(Date.now() - 20_000), new Date(Date.now() - 10_000)]);
    const r = await s.service.takeAsNeeded(me, 'r1');
    expect(r.overMax).toBe(true);
    expect(s.notifications.notify).toHaveBeenCalledTimes(1);
    const [[[n]]] = s.notifications.notify.mock.calls as any;
    expect(n.userId).toBe('c1');
    expect(n.body).not.toMatch(/Napa|mg/);
    expect(n.relatedEntityId).toMatch(/^prn-over:r1:/);
  });

  it('the same offline tap synced twice is one dose', async () => {
    const s = setup();
    const at = hoursAgo(2).toISOString();
    await s.service.takeAsNeeded(me, 'r1', at);
    await s.service.takeAsNeeded(me, 'r1', at);
    expect(s.doses).toHaveLength(1);
  });

  it('a caregiver logging it is recorded as given and the member is told', async () => {
    const s = setup();
    await s.service.takeAsNeeded({ actorId: 'c1', subjectId: 'u1', byCaregiver: true }, 'r1');
    expect(s.doses[0].takenById).toBe('c1');
    expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'dose.give' }), expect.anything());
    expect(s.caregivers.notifyMember).toHaveBeenCalledWith(expect.anything(), 'dose_given', expect.any(String), expect.any(Object));
  });

  it('a future time is taken as now; more than a day back is refused', async () => {
    const s = setup();
    const r = await s.service.takeAsNeeded(me, 'r1', new Date(Date.now() + 3_600_000).toISOString());
    expect(new Date(r.takenAt).getTime()).toBeLessThanOrEqual(Date.now());
    await expect(s.service.takeAsNeeded(me, 'r1', hoursAgo(30).toISOString())).rejects.toThrow('Too long ago');
  });
});
