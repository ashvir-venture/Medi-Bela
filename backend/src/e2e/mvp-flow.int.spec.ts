import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'crypto';
import request from 'supertest';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../notifications/push.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { MissedDoseAlertService } from '../medicine-schedule/missed-dose-alert.service';
import { PrescriptionsService } from '../prescriptions/prescriptions.service';
import { makeTestPrisma, resetDb, signupDetails } from '../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);

/**
 * The whole MVP journey over real HTTP + real Postgres:
 *
 *  register -> upload prescription -> PENDING -> pharmacist reviews, enters
 *  medicines -> sends it (AWAITING_CONFIRMATION) -> patient confirms ->
 *  routine + doses generated -> user logs a dose ->
 *  a missed dose alerts the family (once, privately) -> an active health rule
 *  produced a reminder -> user completes it.
 *
 * Only two things are faked: image storage (Cloudinary) and FCM delivery.
 */
d('MVP end-to-end flow', () => {
  let app: INestApplication;
  const sent: Array<{ tokens: string[]; message: any }> = [];
  const fakePush = {
    isEnabled: () => true,
    send: jest.fn(async (tokens: string[], message: any) => {
      sent.push({ tokens, message });
      return tokens.map((token) => ({ token, ok: true, permanentTokenFailure: false }));
    }),
  };
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(role: 'USER' | 'ADMIN' | 'PHARMACIST', name: string) {
    seq += 1;
    const phone = `+88017200${String(seq).padStart(5, '0')}`;
    const res = await http().post('/api/auth/register').send({ phone, name, password: 'pass1234', ...(await signupDetails(prisma)) }).expect(201);
    if (role !== 'USER') await prisma.user.update({ where: { id: res.body.user.id }, data: { role } });
    return { token: res.body.tokens.accessToken as string, id: res.body.user.id as string, phone };
  }

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
    delete process.env.LLM_API_BASE_URL; delete process.env.LLM_API_KEY;
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(PushService).useValue(fakePush)
      .overrideProvider(CloudinaryService).useValue({
        uploadPrescriptionImage: async (_b: Buffer, name: string) => `https://img.test/${name}`,
        signedImageUrl: (url: string) => url,
      })
      .compile();
    app = mod.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, transformOptions: { enableImplicitConversion: true } }));
    app.setGlobalPrefix('api');
    await app.init();
  });
  afterAll(async () => { await app.close(); await prisma.$disconnect(); });
  beforeEach(async () => {
    await resetDb(prisma);
    await prisma.$executeRawUnsafe('TRUNCATE notices, health_suggestion_rules, health_reminders, health_records, prescriptions CASCADE');
    sent.length = 0; fakePush.send.mockClear();
  });

  it('runs the complete journey and holds every guarantee along the way', async () => {
    const pharmacist = await account('PHARMACIST', 'Pharma Cist');
    const admin = await account('ADMIN', 'Admin Person');
    const patient = await account('USER', 'Rahim Uddin');
    const relative = await account('USER', 'Karim Uddin');
    const stranger = await account('USER', 'Stranger Danger');

    // --- Family set up first (so the missed-dose alert has someone to tell) -----
    await http().post('/api/family').set(auth(patient.token)).send({ name: 'Uddin family' }).expect(201);
    const inv = await http().post('/api/family/invitations').set(auth(patient.token)).send({ phone: relative.phone }).expect(201);
    await http().post(`/api/family/invitations/${inv.body.id}/accept`).set(auth(relative.token)).expect(201);
    const relativeToken = 'fcm-relative-'.padEnd(60, 'x');
    await http().post('/api/notifications/devices').set(auth(relative.token)).send({ token: relativeToken, platform: 'ANDROID' }).expect(204);
    await http().post('/api/notifications/devices').set(auth(patient.token)).send({ token: 'fcm-patient-'.padEnd(60, 'y'), platform: 'ANDROID' }).expect(204);

    // --- A pharmacist-approved rule exists BEFORE the prescription ---------------
    const rule = (await http().post('/api/admin/suggestion-rules').set(auth(admin.token)).send({
      name: 'Diabetes monitoring', conditionType: 'MEDICINE_NAME_CONTAINS', conditionValue: 'metformin, glipizide', suggestedAction: 'Check blood sugar',
    }).expect(201)).body;
    await http().post(`/api/admin/suggestion-rules/${rule.id}/publish`).set(auth(admin.token)).expect(201);

    // --- 1. User uploads a prescription (twice: an offline retry) ---------------
    const clientId = randomUUID();
    const upload = () => http().post('/api/prescriptions').set(auth(patient.token))
      .field('clientId', clientId).attach('image', JPEG, { filename: 'rx.jpg', contentType: 'image/jpeg' });
    const first = (await upload().expect(201)).body;
    const retry = (await upload().expect(201)).body;
    expect(retry.id).toBe(first.id);                                           // duplicate sync prevented
    expect(await prisma.prescription.count()).toBe(1);
    expect(first.status).toBe('PENDING');

    // --- 2. Pending for the user, visible to staff, hidden from everyone else ----
    const mine = (await http().get('/api/prescriptions/mine').set(auth(patient.token)).expect(200)).body;
    expect(mine.map((p: any) => p.id)).toEqual([first.id]);
    expect((await http().get('/api/prescriptions/mine').set(auth(stranger.token)).expect(200)).body).toEqual([]);
    await http().get(`/api/prescriptions/${first.id}`).set(auth(stranger.token)).expect(404);   // ownership
    await http().get(`/api/prescriptions/${first.id}`).set(auth(relative.token)).expect(404);   // family is not owner
    await http().get(`/api/prescriptions/admin/${first.id}`).set(auth(patient.token)).expect(403);
    const pending = (await http().get('/api/prescriptions/admin/pending').set(auth(pharmacist.token)).expect(200)).body;
    expect(pending.map((p: any) => p.id)).toContain(first.id);

    // --- 3. Cannot complete without verified medicines; then enter + complete ----
    await http().post(`/api/prescriptions/admin/${first.id}/complete`).set(auth(pharmacist.token)).expect(400);
    await http().put(`/api/prescriptions/admin/${first.id}/medicines`).set(auth(pharmacist.token)).send({
      medicines: [{ medicineName: 'Metformin 500mg', dosage: '1 tablet', frequency: 'twice daily', duration: '3 days',
        instructions: 'after meals', timesPerDay: 2, scheduleTimes: ['08:00', '20:00'], durationDays: 3 }],
    }).expect(200);
    await http().post(`/api/prescriptions/admin/${first.id}/complete`).set(auth(admin.token)).expect(403);      // admin is read-only
    const done = await http().post(`/api/prescriptions/admin/${first.id}/complete`).set(auth(pharmacist.token)).expect(201);
    expect(done.body.status).toBe('AWAITING_CONFIRMATION');
    expect(done.body.medicines[0].medicineId).toBeTruthy();                      // line linked to the medicine catalog
    expect(await prisma.medicineRoutine.count({ where: { userId: patient.id } })).toBe(0);   // nothing runs before the patient confirms
    await http().post(`/api/prescriptions/admin/${first.id}/complete`).set(auth(pharmacist.token)).expect(409);   // no double completion
    await http().post(`/api/prescriptions/admin/${first.id}/reject`).set(auth(pharmacist.token)).send({ rejectionReason: 'late' }).expect(409);
    expect(await prisma.auditLog.count({ where: { action: 'prescription.prepare', entityId: first.id, actorId: pharmacist.id } })).toBe(1);

    // The patient confirms (the Confirm screen arrives in Round 6; the step already exists).
    await app.get(PrescriptionsService).activate(patient.id, first.id);

    // --- 4. Routine + doses generated (3 days x 2) ------------------------------
    expect(await prisma.medicineRoutine.count({ where: { userId: patient.id } })).toBe(1);
    const doses = await prisma.medicineDose.findMany({ where: { userId: patient.id }, orderBy: { scheduledAt: 'asc' } });
    expect(doses).toHaveLength(6);
    const routines = (await http().get('/api/medicine-schedule/routines').set(auth(patient.token)).expect(200)).body;
    expect(routines).toHaveLength(1);
    expect((await http().get('/api/medicine-schedule/routines').set(auth(stranger.token)).expect(200)).body).toEqual([]);

    // user is told twice (ready to confirm, then active), without medicine detail; patient's device only
    const updates = await prisma.notification.findMany({ where: { userId: patient.id, type: 'PRESCRIPTION_UPDATE' } });
    expect(updates).toHaveLength(2);
    expect(JSON.stringify(updates)).not.toMatch(/Metformin/);
    expect(sent.filter((s) => s.tokens[0].startsWith('fcm-patient'))).toHaveLength(2);

    // --- 5. Optional health suggestion -> reminder, from the pharmacist's rule ----
    const reminders = (await http().get('/api/health-reminders').set(auth(patient.token)).expect(200)).body;
    expect(reminders).toHaveLength(1);
    expect(reminders[0].title).toBe('Check blood sugar');
    expect((await http().get('/api/health-reminders').set(auth(stranger.token)).expect(200)).body).toEqual([]);
    await http().post(`/api/health-reminders/${reminders[0].id}/complete`).set(auth(stranger.token)).send({}).expect(404);
    await http().post(`/api/health-reminders/${reminders[0].id}/complete`).set(auth(patient.token)).send({}).expect(201);
    await http().post(`/api/health-reminders/${reminders[0].id}/complete`).set(auth(patient.token)).send({}).expect(201);  // idempotent
    expect((await prisma.healthReminder.findUnique({ where: { id: reminders[0].id } })).status).toBe('COMPLETED');

    // --- 6. User takes a dose (twice = an offline retry): logged once, stranger blocked ----
    const takenAt = new Date().toISOString();
    await http().post(`/api/medicine-schedule/doses/${doses[5].id}/taken`).set(auth(stranger.token)).send({ takenAt }).expect(404);
    const t1 = (await http().post(`/api/medicine-schedule/doses/${doses[5].id}/taken`).set(auth(patient.token)).send({ takenAt }).expect(201)).body;
    const t2 = (await http().post(`/api/medicine-schedule/doses/${doses[5].id}/taken`).set(auth(patient.token)).send({ takenAt: new Date(Date.now() + 5000).toISOString() }).expect(201)).body;
    expect(t1.status).toBe('TAKEN');
    expect(t2.takenAt).toBe(t1.takenAt);                                         // first timestamp wins; no double log

    // --- 7. User misses a dose -> background job -> family alerted once, privately ----
    const missed = doses[0];
    // Only this dose may be overdue. The routine's real 08:00 / 20:00 doses can
    // fall inside the alert window depending on the hour the test runs (and
    // reading the routines above already marked such a dose MISSED), so every
    // other untaken dose moves a month ahead (else: a second, correct, alert).
    await prisma.$executeRaw`UPDATE medicine_doses
      SET "scheduledAt" = "scheduledAt" + interval '30 days', status = 'PENDING'
      WHERE "userId" = ${patient.id}::uuid AND id <> ${missed.id}::uuid AND status <> 'TAKEN'`;
    await prisma.medicineDose.update({ where: { id: missed.id }, data: { scheduledAt: new Date(Date.now() - 3 * 3_600_000), status: 'PENDING' } });
    sent.length = 0;
    const job = app.get(MissedDoseAlertService);
    await Promise.all([job.run(), job.run()]);                                   // overlapping workers
    await job.run();
    expect((await prisma.medicineDose.findUnique({ where: { id: missed.id } })).status).toBe('MISSED');
    const alerts = await prisma.notification.findMany({ where: { type: 'MISSED_DOSE_FAMILY_ALERT' } });
    expect(alerts.map((a: any) => a.userId)).toEqual([relative.id]);              // relative only: not the patient, not strangers
    const toRelative = sent.filter((s) => s.tokens.includes(relativeToken));
    expect(toRelative).toHaveLength(1);                                          // exactly one push
    const text = JSON.stringify([toRelative[0].message.title, toRelative[0].message.body, toRelative[0].message.data]);
    expect(text).toContain('Rahim Uddin');
    expect(text).not.toMatch(/Metformin|500mg|tablet/i);                          // no unnecessary medical detail
    // ...and the relative can now see the status in-app, the stranger cannot
    const status = (await http().get(`/api/family/members/${patient.id}/status`).set(auth(relative.token)).expect(200)).body;
    expect(status.shared).toBe(true);
    await http().get(`/api/family/members/${patient.id}/status`).set(auth(stranger.token)).expect(404);
    const inbox = (await http().get('/api/notifications').set(auth(relative.token)).expect(200)).body;
    expect(inbox.items.some((n: any) => n.type === 'MISSED_DOSE_FAMILY_ALERT')).toBe(true);
    expect((await http().get('/api/notifications').set(auth(stranger.token)).expect(200)).body.items).toEqual([]);

    // --- 8. Dashboard reflects the journey (server-computed) -----------------------
    const dash = (await http().get('/api/admin/dashboard').set(auth(admin.token)).expect(200)).body;
    expect(dash.totals.prescriptions).toEqual({ total: 1, pending: 0, completed: 1, rejected: 0 });
    expect(dash.totals.families).toBe(1);
    expect(dash.totals.users).toBe(3);
  });

  it('rejection path: user is informed (no reason in the push) and no routine is created', async () => {
    const pharmacist = await account('PHARMACIST', 'Pharma Cist');
    const patient = await account('USER', 'Rahim Uddin');
    await http().post('/api/notifications/devices').set(auth(patient.token)).send({ token: 'fcm-patient-'.padEnd(60, 'y'), platform: 'ANDROID' }).expect(204);
    const rx = (await http().post('/api/prescriptions').set(auth(patient.token)).attach('image', JPEG, { filename: 'rx.jpg', contentType: 'image/jpeg' }).expect(201)).body;
    await http().post(`/api/prescriptions/admin/${rx.id}/reject`).set(auth(pharmacist.token)).send({ rejectionReason: 'Image too blurry to read' }).expect(201);
    expect(await prisma.medicineRoutine.count()).toBe(0);
    const mine = (await http().get('/api/prescriptions/mine').set(auth(patient.token)).expect(200)).body;
    expect(mine[0].status).toBe('REJECTED');
    expect(mine[0].rejectionReason).toBe('Image too blurry to read');            // the user can read it in the app
    expect(JSON.stringify(sent)).not.toMatch(/blurry/);                          // but it never travels via FCM
    expect(sent).toHaveLength(1);
  });

  it('upload rejects non-images and unauthenticated calls', async () => {
    const patient = await account('USER', 'Rahim Uddin');
    await http().post('/api/prescriptions').attach('image', JPEG, { filename: 'rx.jpg', contentType: 'image/jpeg' }).expect(401);
    await http().post('/api/prescriptions').set(auth(patient.token)).attach('image', Buffer.from('%PDF-1.4'), { filename: 'rx.pdf', contentType: 'application/pdf' }).expect(400);
    await http().post('/api/prescriptions').set(auth(patient.token)).field('clientId', randomUUID()).expect(400);   // no file
  });

  describe('authorization sweep (every registered route)', () => {
    /** All routes actually registered with Express, not a hand-kept list. */
    function registeredRoutes(): Array<{ method: string; path: string }> {
      const instance: any = app.getHttpAdapter().getInstance();
      const stack: any[] = (instance.router ?? instance._router).stack;
      const out: Array<{ method: string; path: string }> = [];
      for (const layer of stack) {
        if (!layer.route) continue;
        for (const method of Object.keys(layer.route.methods)) {
          out.push({ method, path: layer.route.path as string });
        }
      }
      return out;
    }
    const concrete = (path: string) => path.replace(/:\w+/g, '00000000-0000-4000-8000-000000000000');
    // Every @Public() route: health, sign-up / sign-in, password reset by SMS
    // code, and the dropdown lookups the signup form needs.
    const PUBLIC = new Set([
      'GET /api/health',
      'POST /api/auth/register',
      'POST /api/auth/login',
      'POST /api/auth/forgot-password',
      'POST /api/auth/reset-password',
      'GET /api/lookups',
      'GET /api/lookups/upazilas',
    ]);

    it('finds the expected number of routes (guards against the sweep silently testing nothing)', () => {
      expect(registeredRoutes().length).toBeGreaterThanOrEqual(65);
    });

    it('ONLY the public routes are reachable without a token; everything else is 401', async () => {
      const unexpectedlyOpen: string[] = [];
      for (const { method, path } of registeredRoutes()) {
        if (PUBLIC.has(`${method.toUpperCase()} ${path}`)) continue;
        const res = await (http() as any)[method](concrete(path)).send({});
        if (res.status !== 401) unexpectedlyOpen.push(`${method.toUpperCase()} ${path} -> ${res.status}`);
      }
      expect(unexpectedlyOpen).toEqual([]);
    });

    it('a normal patient gets 403 on EVERY /admin route and on admin prescription/review routes', async () => {
      const patient = await account('USER', 'Plain Patient');
      const notForbidden: string[] = [];
      let checked = 0;
      for (const { method, path } of registeredRoutes()) {
        if (!/\/admin(\/|$)|\/prescriptions\/admin\//.test(path)) continue;
        checked++;
        const res = await (http() as any)[method](concrete(path)).set(auth(patient.token)).send({});
        if (res.status !== 403) notForbidden.push(`${method.toUpperCase()} ${path} -> ${res.status}`);
      }
      expect(checked).toBeGreaterThanOrEqual(25);
      expect(notForbidden).toEqual([]);
    });
  });

  describe('offline-sync idempotency & auth security', () => {
    it('health records: a retried offline upload (same clientId) never duplicates; ids are per user', async () => {
      const a = await account('USER', 'User A'); const b = await account('USER', 'User B');
      const clientId = randomUUID();
      const body = { type: 'BLOOD_SUGAR', value: '6.1', unit: 'mmol/L', clientId, recordedAt: new Date().toISOString() };
      const r1 = (await http().post('/api/health-records').set(auth(a.token)).send(body).expect(201)).body;
      const r2 = (await http().post('/api/health-records').set(auth(a.token)).send(body).expect(201)).body;
      const both = await Promise.all([1, 2, 3].map(() => http().post('/api/health-records').set(auth(a.token)).send({ ...body, clientId: randomUUID() })));
      expect(r2.id).toBe(r1.id);
      expect(both.every((r) => r.status === 201)).toBe(true);
      expect(await prisma.healthRecord.count({ where: { userId: a.id } })).toBe(4);
      // same clientId from another user is a different record, and A's is not exposed to B
      const rb = (await http().post('/api/health-records').set(auth(b.token)).send(body).expect(201)).body;
      expect(rb.id).not.toBe(r1.id);
      await http().get(`/api/health-records/${r1.id}`).set(auth(b.token)).expect(404);
    });

    it('concurrent identical uploads (same clientId) create one prescription', async () => {
      const a = await account('USER', 'User A');
      const clientId = randomUUID();
      const results = await Promise.all([1, 2, 3].map(() => http().post('/api/prescriptions').set(auth(a.token))
        .field('clientId', clientId).attach('image', JPEG, { filename: 'rx.jpg', contentType: 'image/jpeg' })));
      expect(results.every((r) => r.status === 201)).toBe(true);
      expect(new Set(results.map((r) => r.body.id)).size).toBe(1);
      expect(await prisma.prescription.count()).toBe(1);
    });

    it('login: generic failure, brute force throttled (429), good password blocked while throttled, passwords >= 6 chars', async () => {
      await http().post('/api/auth/register').send({ phone: '+8801730000001', name: 'Short Pw', password: 'abc12', ...(await signupDetails(prisma)) }).expect(400);
      const u = await account('USER', 'Victim');
      const wrong = (phone: string) => http().post('/api/auth/login').send({ phone, password: 'wrong-password' });
      const unknown = await wrong('+8801799999999').expect(401);
      const known = await wrong(u.phone).expect(401);
      expect(unknown.body.message).toBe(known.body.message);                    // no account enumeration
      for (let i = 0; i < 7; i++) await wrong(u.phone).expect(401);   // 8 failures in total are allowed...
      await wrong(u.phone).expect(429);                                          // ...the 9th is blocked
      await http().post('/api/auth/login').send({ phone: u.phone, password: 'pass1234' }).expect(429);
      // a different phone from the same client is unaffected
      const other = await account('USER', 'Other');
      await http().post('/api/auth/login').send({ phone: other.phone, password: 'pass1234' }).expect(200);
    });
  });
});
