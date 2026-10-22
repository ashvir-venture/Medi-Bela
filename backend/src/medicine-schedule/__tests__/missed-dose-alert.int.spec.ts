import { NotificationType, PushStatus } from '@prisma/client';
import { makeTestPrisma, makeUser, resetDb, FAKE_KEY_CONFIG } from '../../test-utils/test-prisma';
import { MissedDoseAlertService } from '../missed-dose-alert.service';
import { NotificationsService } from '../../notifications/notifications.service';
import { DeviceTokensService } from '../../notifications/device-tokens.service';
import { TokenCryptoService } from '../../notifications/token-crypto.service';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

d('Missed-dose pipeline (real Postgres)', () => {
  let push: { isEnabled: jest.Mock; send: jest.Mock };
  let devices: DeviceTokensService;
  let svc: MissedDoseAlertService;
  const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000);

  beforeAll(() => { delete process.env.MISSED_ALERT_MAX_AGE_MINUTES; });
  afterAll(async () => { await prisma.$disconnect(); });

  beforeEach(async () => {
    await resetDb(prisma);
    push = {
      isEnabled: jest.fn(() => true),
      send: jest.fn(async (tokens: string[]) =>
        tokens.map((token) => ({ token, ok: true, permanentTokenFailure: false }))),
    };
    devices = new DeviceTokensService(prisma, new TokenCryptoService(FAKE_KEY_CONFIG));
    const notifications = new NotificationsService(prisma, push as any, devices);
    svc = new MissedDoseAlertService(prisma, notifications);
  });

  async function scenario() {
    const subject = await makeUser(prisma, 'Rahim Uddin');
    const b = await makeUser(prisma, 'Karim', { languagePreference: 'BN' });
    const c = await makeUser(prisma, 'Salma');
    const outsider = await makeUser(prisma, 'Outsider');
    const family = await prisma.family.create({
      data: { members: { create: [
        { userId: subject.id, role: 'OWNER' }, { userId: b.id }, { userId: c.id },
      ] } },
    });
    const routine = await prisma.medicineRoutine.create({
      data: { userId: subject.id, medicineName: 'Metformin', dosage: '500mg', frequency: 'daily', startDate: new Date() },
    });
    const dose = (userId: string, rId: string, h: number, extra = {}) =>
      prisma.medicineDose.create({ data: { routineId: rId, userId, scheduledAt: hoursAgo(h), ...extra } });
    for (const u of [b, c, outsider]) await devices.register(u.id, { token: `tok-${u.id}-xxxxxxxxxxxxxxxxxxxx`, platform: 'ANDROID' } as any);
    return { subject, b, c, outsider, family, routine, dose };
  }

  it('alerts only the OTHER members of the same family, once, with no medicine detail', async () => {
    const { subject, b, c, outsider, routine, dose } = await scenario();
    const missed = await dose(subject.id, routine.id, 3);

    const first = await svc.run();
    expect(first.alerted).toBe(2);

    const rows = await prisma.notification.findMany();
    expect(rows.map((r: any) => r.userId).sort()).toEqual([b.id, c.id].sort());
    expect(rows.every((r: any) => r.type === NotificationType.MISSED_DOSE_FAMILY_ALERT)).toBe(true);
    expect(rows.some((r: any) => r.userId === outsider.id || r.userId === subject.id)).toBe(false);
    for (const r of rows) {
      const text = JSON.stringify([r.title, r.body, r.data]);
      expect(text).toContain('Rahim');
      expect(text).not.toMatch(/Metformin|500mg/);
      expect(r.data).toEqual({ memberUserId: subject.id });
    }
    // Recipient language respected (BN).
    expect(rows.find((r: any) => r.userId === b.id).title).toBe('ওষুধ মিস হয়েছে');
    expect(push.send).toHaveBeenCalledTimes(2);
    expect((await prisma.medicineDose.findUnique({ where: { id: missed.id } })).status).toBe('MISSED');
  });

  it('never alerts twice for the same missed dose (sequential reruns)', async () => {
    const { subject, routine, dose } = await scenario();
    await dose(subject.id, routine.id, 3);
    await svc.run(); await svc.run(); await svc.run();
    expect(await prisma.notification.count()).toBe(2);
    expect(push.send).toHaveBeenCalledTimes(2);
  });

  it('never alerts twice under concurrent runs (two workers / overlapping cron)', async () => {
    const { subject, routine, dose } = await scenario();
    await dose(subject.id, routine.id, 3);
    await Promise.all([svc.run(), svc.run(), svc.run(), svc.run()]);
    expect(await prisma.notification.count()).toBe(2);
    expect(push.send).toHaveBeenCalledTimes(2);
  });

  it('does not alert when the subject turned off family sharing, and does not retry later', async () => {
    const { subject, routine, dose } = await scenario();
    await prisma.user.update({ where: { id: subject.id }, data: { profileVisibleToFamily: false } });
    const missed = await dose(subject.id, routine.id, 3);
    await svc.run();
    expect(await prisma.notification.count()).toBe(0);
    expect((await prisma.medicineDose.findUnique({ where: { id: missed.id } })).familyAlertProcessedAt).not.toBeNull();
    await prisma.user.update({ where: { id: subject.id }, data: { profileVisibleToFamily: true } });
    await svc.run();
    expect(await prisma.notification.count()).toBe(0);
  });

  it('does not alert for doses within grace, already taken, or stale backlog', async () => {
    const { subject, routine, dose } = await scenario();
    await dose(subject.id, routine.id, 0.5);                                   // inside 2h grace
    await dose(subject.id, routine.id, 3, { status: 'TAKEN', takenAt: new Date() });
    const stale = await dose(subject.id, routine.id, 30);                      // older than alert window
    await svc.run();
    expect(await prisma.notification.count()).toBe(0);
    expect((await prisma.medicineDose.findUnique({ where: { id: stale.id } })).familyAlertProcessedAt).not.toBeNull();
  });

  it('a user with no family causes no alerts and no errors', async () => {
    const loner = await makeUser(prisma, 'Loner');
    const r = await prisma.medicineRoutine.create({ data: { userId: loner.id, medicineName: 'X', dosage: '1', frequency: 'd', startDate: new Date() } });
    await prisma.medicineDose.create({ data: { routineId: r.id, userId: loner.id, scheduledAt: hoursAgo(3) } });
    await expect(svc.run()).resolves.toMatchObject({ alerted: 0 });
  });

  it('respects recipients who disabled notifications (inbox row kept, no push) and removes dead tokens', async () => {
    const { subject, b, c, routine, dose } = await scenario();
    await prisma.user.update({ where: { id: b.id }, data: { notificationsEnabled: false } });
    push.send.mockImplementation(async (tokens: string[]) =>
      tokens.map((token) => ({ token, ok: false, permanentTokenFailure: true, errorCode: 'messaging/registration-token-not-registered' })));
    await dose(subject.id, routine.id, 3);
    await svc.run();
    const bRow = await prisma.notification.findFirst({ where: { userId: b.id } });
    const cRow = await prisma.notification.findFirst({ where: { userId: c.id } });
    expect(bRow.pushStatus).toBe(PushStatus.SKIPPED);
    expect(cRow.pushStatus).toBe(PushStatus.SKIPPED);       // its only device was dead
    expect(push.send).toHaveBeenCalledTimes(1);              // only c was attempted
    expect(await prisma.deviceToken.count({ where: { userId: c.id } })).toBe(0); // dead token pruned
  });

  it('retries a transient push failure and then stops once SENT', async () => {
    const { subject, routine, dose } = await scenario();
    let calls = 0;
    push.send.mockImplementation(async (tokens: string[]) => {
      calls++;
      return tokens.map((token) => ({ token, ok: calls > 2, permanentTokenFailure: false, errorCode: 'messaging/unavailable' }));
    });
    await dose(subject.id, routine.id, 3);
    await svc.run();                                       // attempt 1 (both fail -> PENDING)
    const notifications = new NotificationsService(prisma, push as any, devices);
    await notifications.dispatchPending();                 // attempt 2 -> b ok? calls 3,4 succeed
    await notifications.dispatchPending();                 // nothing left
    const rows = await prisma.notification.findMany();
    expect(rows.every((r: any) => r.pushStatus === 'SENT')).toBe(true);
    const total = push.send.mock.calls.length;
    await notifications.dispatchPending();
    expect(push.send.mock.calls.length).toBe(total);       // never re-sent
  });
});
