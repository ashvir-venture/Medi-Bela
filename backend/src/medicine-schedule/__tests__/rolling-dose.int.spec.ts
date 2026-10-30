import { makeTestPrisma, makeUser, resetDb } from '../../test-utils/test-prisma';
import { RollingDoseJob } from '../rolling-dose.job';
import { ROLLING_HORIZON_DAYS } from '../../prescriptions/lib/routine-generation.service';
import { addAppDays, startOfAppDay } from '../../common/utils/time.util';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

d('Rolling dose generation (real Postgres)', () => {
  const now = new Date('2026-10-29T06:00:00.000Z'); // 12:00 in Dhaka
  const today = startOfAppDay(now);
  let job: RollingDoseJob;

  afterAll(async () => { await prisma.$disconnect(); });

  beforeEach(async () => {
    await resetDb(prisma);
    job = new RollingDoseJob(prisma);
  });

  async function routine(extra: Record<string, unknown>) {
    const user = await makeUser(prisma, 'Rahim');
    return prisma.medicineRoutine.create({
      data: {
        userId: user.id, medicineName: 'Metformin', dosage: '500mg', frequency: 'twice daily',
        startDate: today, scheduleTimes: JSON.stringify(['08:00', '20:00']), ...extra,
      },
    });
  }

  it('extends a continuous routine to the horizon, then does nothing until the horizon moves', async () => {
    const r = await routine({ endDate: null, generatedUntil: addAppDays(today, 3) });

    await expect(job.run(now)).resolves.toBe(2 * (ROLLING_HORIZON_DAYS - 3));
    await expect(job.run(now)).resolves.toBe(0);
    expect((await prisma.medicineRoutine.findUnique({ where: { id: r.id } })).generatedUntil)
      .toEqual(addAppDays(today, ROLLING_HORIZON_DAYS));

    // Next day: one more day of doses.
    await expect(job.run(addAppDays(now, 1))).resolves.toBe(2);
  });

  it('stops at the end of the course', async () => {
    await routine({ endDate: addAppDays(today, 4), generatedUntil: addAppDays(today, 2) });
    await expect(job.run(now)).resolves.toBe(2 * 3); // days 2, 3, 4
    await expect(job.run(addAppDays(now, 1))).resolves.toBe(0);
  });

  it('never creates a day twice under overlapping runs', async () => {
    const r = await routine({ endDate: null, generatedUntil: today });
    await Promise.all([job.run(now), job.run(now), job.run(now)]);
    // Today's 08:00 is already past at 12:00: since Round 10 the job never
    // generates a dose before now (no back-fill), so one dose fewer.
    expect(await prisma.medicineDose.count({ where: { routineId: r.id } })).toBe(2 * ROLLING_HORIZON_DAYS - 1);
  });

  // One run must cover every routine: each needs extending once a day, and a
  // 200-a-run job (24 runs a day) fell behind above ~4,800 routines.
  it('extends every routine in one run, not just the first batch', async () => {
    const user = await makeUser(prisma, 'Rahim');
    await prisma.medicineRoutine.createMany({
      data: Array.from({ length: 210 }, () => ({
        userId: user.id, medicineName: 'Metformin', dosage: '500mg', frequency: 'twice daily', startDate: today,
        scheduleTimes: JSON.stringify(['08:00', '20:00']), generatedUntil: addAppDays(today, ROLLING_HORIZON_DAYS - 1),
      })),
    });
    await expect(job.run(now)).resolves.toBe(2 * 210);
    expect(await prisma.medicineRoutine.count({ where: { generatedUntil: addAppDays(today, ROLLING_HORIZON_DAYS) } })).toBe(210);
  });

  it('finished courses that are already complete do not block routines behind them', async () => {
    const user = await makeUser(prisma, 'Rahim');
    // Ending soon and fully generated (up to the day after the end): nothing to do,
    // but they still match the job's query and sort first.
    await prisma.medicineRoutine.createMany({
      data: Array.from({ length: 210 }, () => ({
        userId: user.id, medicineName: 'Short course', dosage: '1', frequency: 'daily', startDate: today,
        scheduleTimes: JSON.stringify(['08:00']), endDate: addAppDays(today, 2), generatedUntil: addAppDays(today, 3),
      })),
    });
    const behind = await routine({ endDate: null, generatedUntil: addAppDays(today, ROLLING_HORIZON_DAYS - 1) });
    await expect(job.run(now)).resolves.toBe(2);
    expect((await prisma.medicineRoutine.findUnique({ where: { id: behind.id } })).generatedUntil)
      .toEqual(addAppDays(today, ROLLING_HORIZON_DAYS));
  });

  it('leaves routines from before Round 4 (no scheduleTimes) and inactive ones alone', async () => {
    await routine({ scheduleTimes: null, generatedUntil: today });
    await routine({ active: false, generatedUntil: today });
    await expect(job.run(now)).resolves.toBe(0);
  });
});
