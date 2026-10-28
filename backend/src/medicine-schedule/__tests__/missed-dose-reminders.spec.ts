import { DoseStatus, NotificationType } from '@prisma/client';
import { MissedDoseAlertService, BACKSTOP_AFTER_MINUTES } from '../missed-dose-alert.service';
import { missedGraceMinutes, DEFAULT_MISSED_GRACE_MINUTES } from '../lib/dose-status.util';

const NOW = new Date('2026-10-29T08:45:00.000Z');
const minutesAgo = (m: number) => new Date(NOW.getTime() - m * 60_000);

/** Prisma fake: `pendingForBackstop` answers the backstop query, `missed` the family-alert candidates. */
function setup(opts: { pendingForBackstop?: any[]; missed?: any[] } = {}) {
  const createdRows: any[] = [];
  const familyLookups = jest.fn(async () => ({ familyId: 'f1' }));
  const prisma: any = {
    medicineDose: {
      updateMany: jest.fn(async () => ({ count: 1 })),
      findMany: jest.fn(async ({ where }: any) =>
        where.status === DoseStatus.PENDING ? opts.pendingForBackstop ?? [] : opts.missed ?? [],
      ),
    },
    familyMember: {
      findUnique: familyLookups,
      findMany: jest.fn(async () => [{ user: { id: 'relative', languagePreference: 'EN' } }]),
    },
    $transaction: jest.fn(async (cb: any) => cb(prisma)),
  };
  const notifications: any = {
    createMany: jest.fn(async (rows: any[]) => {
      createdRows.push(...rows);
      return rows.map((_r, i) => `n${createdRows.length - rows.length + i}`);
    }),
    dispatch: jest.fn(async () => undefined),
  };
  return { service: new MissedDoseAlertService(prisma, notifications), prisma, notifications, createdRows, familyLookups };
}

describe('missed-dose grace default', () => {
  const saved = process.env.DOSE_MISSED_GRACE_MINUTES;
  afterEach(() => {
    if (saved === undefined) delete process.env.DOSE_MISSED_GRACE_MINUTES;
    else process.env.DOSE_MISSED_GRACE_MINUTES = saved;
  });

  it('defaults to 62 minutes (last snoozed reminder at +60 plus its 2-minute ring)', () => {
    delete process.env.DOSE_MISSED_GRACE_MINUTES;
    expect(DEFAULT_MISSED_GRACE_MINUTES).toBe(62);
    expect(missedGraceMinutes()).toBe(62);
  });

  it('a value set in .env still wins', () => {
    process.env.DOSE_MISSED_GRACE_MINUTES = '120';
    expect(missedGraceMinutes()).toBe(120);
  });
});

describe('reminder backstop push', () => {
  beforeEach(() => delete process.env.DOSE_MISSED_GRACE_MINUTES);

  it('queries untaken doses between the second reminder and the missed cutoff, reminders on only', async () => {
    const { service, prisma } = setup();
    await service.sendBackstops(NOW);

    const { where } = prisma.medicineDose.findMany.mock.calls[0][0];
    expect(where.status).toBe(DoseStatus.PENDING);
    expect(where.scheduledAt.lte).toEqual(minutesAgo(BACKSTOP_AFTER_MINUTES));
    expect(where.scheduledAt.gte).toEqual(minutesAgo(62));
    expect(where.user).toMatchObject({ medicineRemindersEnabled: true });
  });

  it('sends one neutral, data-only-ready notification per user and scheduled time, to the patient', async () => {
    const at = minutesAgo(31);
    const { service, createdRows, notifications } = setup({
      pendingForBackstop: [
        { id: 'd1', userId: 'u1', scheduledAt: at, user: { languagePreference: 'EN' } },
        { id: 'd2', userId: 'u1', scheduledAt: at, user: { languagePreference: 'EN' } },
        { id: 'd3', userId: 'u2', scheduledAt: at, user: { languagePreference: 'BN' } },
      ],
    });

    await expect(service.sendBackstops(NOW)).resolves.toBe(2);

    expect(createdRows).toHaveLength(2);
    expect(createdRows[0]).toMatchObject({
      userId: 'u1',
      type: NotificationType.MEDICINE_REMINDER,
      relatedEntityId: `backstop:${at.toISOString()}`,
      data: { kind: 'backstop', scheduledAt: at.toISOString(), doseIds: 'd1,d2' },
    });
    expect(createdRows[1].userId).toBe('u2');
    // No medicine names anywhere in what leaves the server.
    expect(JSON.stringify(createdRows)).not.toMatch(/Napa|tablet/i);
    expect(notifications.dispatch).toHaveBeenCalledWith(['n0', 'n1']);
  });
});

describe('family alert and the reminder switch', () => {
  const missedDose = (medicineRemindersEnabled: boolean) => ({
    id: 'd1',
    userId: 'patient',
    user: { name: 'Rahim', accountStatus: 'ACTIVE', profileVisibleToFamily: true, medicineRemindersEnabled },
  });

  it('alerts the family when reminders are on', async () => {
    const { service, createdRows } = setup({ missed: [missedDose(true)] });
    await service.run(NOW);
    expect(createdRows.filter((r) => r.type === NotificationType.MISSED_DOSE_FAMILY_ALERT)).toHaveLength(1);
  });

  it('claims the dose but tells nobody when the patient turned reminders off', async () => {
    const { service, createdRows, familyLookups, prisma } = setup({ missed: [missedDose(false)] });
    await service.run(NOW);

    expect(familyLookups).not.toHaveBeenCalled();
    expect(createdRows.filter((r) => r.type === NotificationType.MISSED_DOSE_FAMILY_ALERT)).toHaveLength(0);
    expect(prisma.medicineDose.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ id: 'd1', familyAlertProcessedAt: null }) }),
    );
  });
});
