import { extendRoutine, pauseSchedules, RollingDoseJob } from '../rolling-dose.job';
import { startOfAppDay } from '../../common/utils/time.util';

const DAY = 86_400_000;

function fakePrisma() {
  const created: Date[] = [];
  const tx: any = {
    medicineRoutine: { updateMany: jest.fn(async () => ({ count: 1 })) },
    medicineDose: {
      createMany: jest.fn(async ({ data }: any) => {
        created.push(...data.map((d: any) => d.scheduledAt));
        return { count: data.length };
      }),
    },
  };
  const prisma: any = { $transaction: async (fn: any) => fn(tx), medicineRoutine: { findMany: jest.fn(async () => []) } };
  return { prisma, tx, created };
}

describe('extendRoutine after a pause', () => {
  const now = new Date('2026-10-30T10:00:00Z');

  it('a long pause (generatedUntil weeks ago) starts from today and skips times already past: no back-filled doses', async () => {
    const f = fakePrisma();
    const stored = new Date(now.getTime() - 30 * DAY);
    await extendRoutine(f.prisma, { id: 'r1', userId: 'u1', scheduleTimes: '["08:00","20:00"]', endDate: null, generatedUntil: stored }, now);
    expect(f.created.length).toBeGreaterThan(0);
    expect(f.created.every((d) => d > now)).toBe(true);
    expect(Math.min(...f.created.map((d) => d.getTime()))).toBeLessThan(now.getTime() + DAY);
    // Compare-and-set on the value as stored.
    expect(f.tx.medicineRoutine.updateMany.mock.calls[0][0].where).toEqual({ id: 'r1', generatedUntil: stored });
  });

  it('paused today (generatedUntil = start of today): regenerates the rest of today, nothing before now', async () => {
    const f = fakePrisma();
    await extendRoutine(f.prisma, { id: 'r1', userId: 'u1', scheduleTimes: '["08:00","20:00"]', endDate: null, generatedUntil: startOfAppDay(now) }, now);
    expect(f.created.every((d) => d > now)).toBe(true);
    expect(Math.min(...f.created.map((d) => d.getTime()))).toBeLessThan(now.getTime() + DAY / 2);
  });
});

describe('pauseSchedules', () => {
  it('deletes future PENDING doses of regenerable routines and resets generatedUntil to the start of today', async () => {
    const now = new Date('2026-10-30T10:00:00Z');
    const tx: any = {
      medicineDose: { deleteMany: jest.fn(async () => ({ count: 3 })) },
      medicineRoutine: { updateMany: jest.fn(async () => ({ count: 1 })) },
    };
    await pauseSchedules(tx, 'u1', now);
    const doseWhere = tx.medicineDose.deleteMany.mock.calls[0][0].where;
    expect(doseWhere).toMatchObject({ userId: 'u1', status: 'PENDING', scheduledAt: { gt: now } });
    expect(doseWhere.routine).toMatchObject({ active: true, scheduleTimes: { not: null } });
    const update = tx.medicineRoutine.updateMany.mock.calls[0][0];
    expect(update.data.generatedUntil).toEqual(startOfAppDay(now));
    expect(update.where.generatedUntil).toEqual({ gt: startOfAppDay(now) });
  });
});

describe('RollingDoseJob', () => {
  it('only extends routines of ACTIVE accounts', async () => {
    const f = fakePrisma();
    await new RollingDoseJob(f.prisma).run(new Date('2026-10-30T10:00:00Z'));
    expect(f.prisma.medicineRoutine.findMany.mock.calls[0][0].where.user).toEqual({ accountStatus: 'ACTIVE' });
  });
});
