import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { readFileSync } from 'fs';
import { join } from 'path';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../notifications/push.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { makeTestPrisma, resetDb, signupDetails } from '../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

/**
 * Rounds 15-16 over real HTTP + Postgres (needs pending SQL 014 and 015):
 * conditions, limits and the caregiver's out-of-range alert, care settings,
 * ticks and logs, the emergency alert, visits with a private doctor, test
 * results by the owner's test list, record-only prescriptions with photos,
 * and who may do each (patient, caregiver, other member, stranger).
 */
d('Rounds 15-16: my care, readings, health records', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(name: string) {
    seq += 1;
    const phone = `017800${String(seq).padStart(5, '0')}`;
    const res = await http()
      .post('/api/auth/register')
      .send({ phone, name, password: 'pass1234', acceptTerms: true, ...(await signupDetails(prisma)) })
      .expect(201);
    return { token: res.body.tokens.accessToken as string, id: res.body.user.id as string, phone };
  }

  async function family(carer: { token: string }, ...members: { token: string; phone: string }[]) {
    await http().post('/api/family').set(auth(carer.token)).send({ name: 'Home' }).expect(201);
    for (const m of members) {
      const inv = await http().post('/api/family/invitations').set(auth(carer.token)).send({ phone: m.phone }).expect(201);
      await http().post(`/api/family/invitations/${inv.body.id}/accept`).set(auth(m.token)).expect(201);
    }
  }

  const alertsTo = (userId: string, kind: string) =>
    prisma.notification.findMany({ where: { userId, data: { path: ['kind'], equals: kind } } });

  /**
   * Other specs TRUNCATE diagnostic_tests CASCADE, which empties test_kinds
   * (it points at diagnostic_tests): put the owner's test list back from
   * pending SQL 015 when it is missing.
   */
  async function ensureTestList() {
    if ((await prisma.testKind.count()) > 0) return;
    const sql = readFileSync(join(__dirname, '../../prisma/pending-sql/015_round16_health_records.sql'), 'utf8');
    const seed = sql.slice(sql.indexOf('INSERT INTO "test_kinds"'));
    for (const statement of seed.split(/;\s*\n/).map((x) => x.trim()).filter(Boolean)) {
      await prisma.$executeRawUnsafe(statement);
    }
  }

  beforeAll(async () => {
    await ensureTestList();
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(PushService).useValue({ isEnabled: () => false, send: jest.fn(async () => []) })
      .overrideProvider(CloudinaryService).useValue({
        signedImageUrl: (url: string) => `${url}?signed`,
        uploadPrivateImage: jest.fn(async () => 'https://res.cloudinary.com/x/image/authenticated/v1/records/p1.jpg'),
        uploadPrescriptionImage: jest.fn(async () => 'https://res.cloudinary.com/x/image/authenticated/v1/prescriptions/p.jpg'),
        deleteImageByUrl: jest.fn(async () => undefined),
        isConfigured: () => true,
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
    await prisma.$executeRawUnsafe('TRUNCATE audit_logs CASCADE');
  });

  it('lookups carry the 8 conditions and the test list with fields (EN/BN)', async () => {
    const res = await http().get('/api/lookups').expect(200);
    expect(res.body.conditions.map((c: any) => c.code)).toEqual(['diabetes', 'bp', 'heart', 'kidney', 'cancer', 'asthma', 'thyroid', 'pregnancy']);
    expect(res.body.conditions[0]).toMatchObject({ nameEn: 'Diabetes', nameBn: 'ডায়াবেটিস' });
    const kidney = res.body.testKinds.find((k: any) => k.code === 'kidney');
    expect(kidney.fields.map((f: any) => [f.code, f.unit])).toEqual([['creat', 'mg/dL'], ['urea', 'mg/dL']]);
  });

  it('conditions, the sign-up step, height and the overview', async () => {
    const me = await account('Abba');
    let o = await http().get('/api/care').set(auth(me.token)).expect(200);
    expect(o.body).toMatchObject({ conditions: [], careStepDone: false, limits: null, heightCm: null });
    await http().put('/api/care/conditions').set(auth(me.token)).send({ codes: ['bp', 'diabetes'] }).expect(200);
    await http().put('/api/care/conditions').set(auth(me.token)).send({ codes: ['malaria'] }).expect(400);
    await http().patch('/api/users/me').set(auth(me.token)).send({ heightCm: 165 }).expect(200);
    o = await http().get('/api/care').set(auth(me.token)).expect(200);
    expect(o.body).toMatchObject({ conditions: ['diabetes', 'bp'], careStepDone: true, heightCm: 165 });
  });

  it('readings: no limits = no range and no alert; saved limits mark and tell the caregiver once, without values', async () => {
    const carer = await account('Rafi');
    const abba = await account('Abba');
    await family(carer, abba);
    const bp = { type: 'BLOOD_PRESSURE', value: '150/95', systolic: 150, diastolic: 95, pulse: 80, bpArm: 'LEFT', measurements: 2 };

    const first = await http().post('/api/health-records').set(auth(abba.token)).send(bp).expect(201);
    expect(first.body.rangeState).toBeNull();
    expect(await alertsTo(carer.id, 'reading_alert')).toHaveLength(0);

    await http().put('/api/care/limits').set(auth(abba.token)).send({ bpSystolicHigh: 140, bpDiastolicHigh: 90 }).expect(200);
    const second = await http().post('/api/health-records').set(auth(abba.token)).send(bp).expect(201);
    expect(second.body.rangeState).toBe('ABOVE');
    const alerts = await alertsTo(carer.id, 'reading_alert');
    expect(alerts).toHaveLength(1);
    expect(alerts[0].body).not.toMatch(/150|95/);

    // "Tell my family" off: no more alerts.
    await http().put('/api/care/limits').set(auth(abba.token)).send({ notifyFamily: false }).expect(200);
    await http().post('/api/health-records').set(auth(abba.token)).send(bp).expect(201);
    expect(await alertsTo(carer.id, 'reading_alert')).toHaveLength(1);

    // A sugar reading in mmol/L with its context; bad combinations refused.
    const sugar = await http().post('/api/health-records').set(auth(abba.token))
      .send({ type: 'BLOOD_SUGAR', value: '6.1', numericValue: 6.1, sugarContext: 'FASTING' }).expect(201);
    expect(sugar.body.rangeState).toBeNull(); // no sugar limits saved
    await http().post('/api/health-records').set(auth(abba.token)).send({ type: 'WEIGHT', value: '70', sugarContext: 'FASTING' }).expect(400);
    await http().put('/api/care/limits').set(auth(abba.token)).send({ fastingLow: 7, fastingHigh: 5 }).expect(400);
  });

  it('who may act: the caregiver adds for a member (tagged, audited, member told); others get 404', async () => {
    const carer = await account('Rafi');
    const abba = await account('Abba');
    const sister = await account('Mitu');
    const stranger = await account('Stranger');
    await family(carer, abba, sister);

    const r = await http().post(`/api/health-records?forUserId=${abba.id}`).set(auth(carer.token))
      .send({ type: 'WEIGHT', value: '68', numericValue: 68 }).expect(201);
    expect(r.body.byCaregiver).toBe(true);
    expect(r.body.enteredById).toBeUndefined();
    await http().put(`/api/care/settings/diabetes?forUserId=${abba.id}`).set(auth(carer.token))
      .send({ pen: { openedOn: '2026-11-01', lifeDays: 28, remindDaysBefore: 3 } }).expect(200);
    const audits = await prisma.auditLog.findMany({ where: { subjectUserId: abba.id } });
    expect(audits.map((a: any) => a.action).sort()).toEqual(['care.settings', 'health_record.create']);
    expect((await alertsTo(abba.id, 'caregiver_action')).length).toBeGreaterThanOrEqual(2);

    for (const other of [sister, stranger]) {
      await http().get(`/api/care?forUserId=${abba.id}`).set(auth(other.token)).expect(404);
      await http().get(`/api/records?forUserId=${abba.id}`).set(auth(other.token)).expect(404);
      await http().post(`/api/health-records?forUserId=${abba.id}`).set(auth(other.token)).send({ type: 'WEIGHT', value: '1' }).expect(404);
    }

    // Hide from family: the caregiver loses access too.
    await prisma.user.update({ where: { id: abba.id }, data: { profileVisibleToFamily: false } });
    await http().get(`/api/care?forUserId=${abba.id}`).set(auth(carer.token)).expect(404);
  });

  it('settings, ticks, logs, questions and the emergency alert', async () => {
    const carer = await account('Rafi');
    const mitu = await account('Mitu');
    await family(carer, mitu);
    const t = auth(mitu.token);

    await http().put('/api/care/settings/pregnancy').set(t).send({ dueDate: '2027-04-01', habits: ['ifa', 'ca'] }).expect(200);
    await http().put('/api/care/settings/pregnancy').set(t).send({ triggers: ['dust'] }).expect(400); // asthma field
    await http().put('/api/care/settings/kidney').set(t).send({ dialysis: true, dialysisDays: [1, 4], dialysisTime: '09:00' }).expect(200);
    await http().put('/api/care/ticks').set(t).send({ key: 'habit:ifa', day: new Date().toISOString().slice(0, 10), done: true }).expect(200);
    await http().put('/api/care/ticks').set(t).send({ key: 'bad key', day: '2026-11-11', done: true }).expect(400);
    const kicks = await http().post('/api/care/logs').set(t).send({ kind: 'KICKS', conditionCode: 'pregnancy', data: { count: 10, minutes: 30 }, clientId: '0d0d0d0d-0000-4000-8000-000000000001' }).expect(201);
    const again = await http().post('/api/care/logs').set(t).send({ kind: 'KICKS', conditionCode: 'pregnancy', data: { count: 10, minutes: 30 }, clientId: '0d0d0d0d-0000-4000-8000-000000000001' }).expect(201);
    expect(again.body.id).toBe(kicks.body.id); // offline retry, no duplicate
    await http().post('/api/care/questions').set(t).send({ text: 'Can I travel by bus?' }).expect(201);

    const o = await http().get('/api/care').set(t).expect(200);
    expect(o.body.settings.pregnancy).toEqual({ dueDate: '2027-04-01', habits: ['ifa', 'ca'] });
    expect(o.body.settings.kidney).toEqual({ dialysis: true, dialysisDays: [1, 4], dialysisTime: '09:00' });
    expect(o.body.ticks).toHaveLength(1);
    expect(o.body.logs).toHaveLength(1);
    expect(o.body.questions.map((q: any) => q.text)).toEqual(['Can I travel by bus?']);

    const help = await http().post('/api/care/alert-family').set(t).expect(200);
    expect(help.body).toEqual({ notified: true });
    expect(await alertsTo(carer.id, 'help_alert')).toHaveLength(1);
    // The caregiver pressing it has nobody to tell.
    expect((await http().post('/api/care/alert-family').set(auth(carer.token)).expect(200)).body).toEqual({ notified: false });
  });

  it('records: a visit with a private doctor, a test result with values and a photo, a record-only prescription', async () => {
    const me = await account('Abba');
    const t = auth(me.token);
    const doctor = await prisma.doctor.create({ data: { name: 'Dr Catalog Rahman', chamber: 'Popular, Dhanmondi' } });

    const search = await http().get('/api/records/doctors/search?q=dr cat').set(t).expect(200);
    expect(search.body.catalog.map((d: any) => d.name)).toEqual(['Dr Catalog Rahman']);
    expect(search.body.catalog[0].phone).toBeUndefined();

    const visit = await http().post('/api/records/appointments').set(t)
      .send({ date: '2026-12-01', time: '17:00', newDoctor: { name: 'Dr Karim', chamber: 'Ibn Sina' }, conditionCode: 'bp' }).expect(201);
    expect(visit.body.doctor).toMatchObject({ source: 'MINE', name: 'Dr Karim' });
    // Typed doctors never reach the pharmacists' catalog.
    expect(await prisma.doctor.count()).toBe(1);
    await http().post('/api/records/appointments').set(t).send({ date: '2026-12-02', newDoctor: { name: 'dr karim' } }).expect(201);
    expect(await prisma.myDoctor.count({ where: { userId: me.id } })).toBe(1); // reused
    const anc = await http().post('/api/records/appointments').set(t).send({ kind: 'ANC', number: 2, date: '2026-12-05', doctorId: doctor.id }).expect(201);
    const done = await http().patch(`/api/records/appointments/${anc.body.id}`).set(t).send({ done: true }).expect(200);
    expect(done.body.done).toBe(true);
    await http().post('/api/records/appointments').set(t).send({ date: '2026-12-05', time: '25:00' }).expect(400);

    const test = await http().post('/api/records/tests').set(t).send({
      testKindCode: 'kidney', status: 'DONE', date: '2026-11-06', lab: 'Popular', findings: 'Normal',
      values: [{ fieldCode: 'creat', value: 1.3 }, { name: 'Uric acid', value: 6.2, unit: 'mg/dL' }],
    }).expect(201);
    expect(test.body.values.map((v: any) => [v.name, v.value, v.unit])).toEqual([['Creatinine', 1.3, 'mg/dL'], ['Uric acid', 6.2, 'mg/dL']]);
    const photo = await http().post(`/api/records/tests/${test.body.id}/photos`).set(t)
      .attach('image', Buffer.from([0xff, 0xd8, 0xff]), { filename: 'r.jpg', contentType: 'image/jpeg' }).expect(201);
    expect(photo.body.imageUrl).toMatch(/\?signed$/);
    await http().post('/api/records/tests').set(t).send({ otherName: 'Vitamin D', date: '2026-12-10', fasting: true }).expect(201);

    const rx = await http().post('/api/records/prescriptions').set(t).send({ date: '2026-10-01', note: 'Old one' }).expect(201);
    await http().post(`/api/records/prescriptions/${rx.body.id}/photos`).set(t)
      .attach('image', Buffer.from([0xff, 0xd8, 0xff]), { filename: 'p.jpg', contentType: 'image/jpeg' }).expect(201);
    // Never in the pharmacist queue, no medicines.
    expect(await prisma.prescription.count({ where: { userId: me.id } })).toBe(0);
    expect(await prisma.medicineRoutine.count({ where: { userId: me.id } })).toBe(0);

    const o = await http().get('/api/records').set(t).expect(200);
    expect(o.body.appointments).toHaveLength(3);
    expect(o.body.tests).toHaveLength(2);
    expect(o.body.tests.find((x: any) => x.id === test.body.id).photos[0].imageUrl).toMatch(/\?signed$/);
    expect(o.body.prescriptions[0].photos).toHaveLength(1);
    expect(JSON.stringify(o.body)).not.toContain('records/p1.jpg"'); // only signed links go out

    const stranger = await account('Stranger');
    await http().delete(`/api/records/tests/${test.body.id}`).set(auth(stranger.token)).expect(404);
    await http().delete(`/api/records/tests/${test.body.id}`).set(t).expect(200);
    expect(await prisma.recordPhoto.count({ where: { ownTestId: test.body.id } })).toBe(0);
  });
});
