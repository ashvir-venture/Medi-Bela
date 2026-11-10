import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../notifications/push.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { MissedDoseAlertService } from '../medicine-schedule/missed-dose-alert.service';
import { makeTestPrisma, resetDb, signupDetails } from '../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;
const MIN = 60_000;

/**
 * Round 14 over real HTTP + Postgres: the user's own reminder timings, On
 * time / Late, the caregiver marking a member's dose ("I gave it") and
 * switching easy mode, and who may do each.
 */
d('Round 14: own timings, On time / Late, caregiver gives and easy mode', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(name: string) {
    seq += 1;
    const phone = `017700${String(seq).padStart(5, '0')}`;
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

  /** A self-added medicine with one dose moved to [minutesAgo] before now. */
  async function dueDose(patient: { token: string; id: string }, minutesAgo: number) {
    const add = await http().post('/api/medicine-schedule/routines').set(auth(patient.token)).send({
      medicineName: 'Napa', timesPerDay: 1, scheduleTimes: ['08:00'], durationDays: 10,
    }).expect(201);
    const dose = await prisma.medicineDose.findFirst({ where: { routineId: add.body.id }, orderBy: { scheduledAt: 'asc' } });
    await prisma.medicineDose.update({ where: { id: dose.id }, data: { scheduledAt: new Date(Date.now() - minutesAgo * MIN) } });
    return dose.id as string;
  }

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(PushService).useValue({ isEnabled: () => false, send: jest.fn(async () => []) })
      .overrideProvider(CloudinaryService).useValue({ signedImageUrl: (url: string) => url })
      .compile();
    app = mod.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, transformOptions: { enableImplicitConversion: true } }));
    app.setGlobalPrefix('api');
    await app.init();
  });
  afterAll(async () => { await app.close(); await prisma.$disconnect(); });
  beforeEach(async () => {
    delete process.env.DOSE_MISSED_GRACE_MINUTES;
    await resetDb(prisma);
    await prisma.$executeRawUnsafe('TRUNCATE audit_logs CASCADE');
  });

  it('own timings: defaults, saving, back to default, and the family alert must come after the last ring', async () => {
    const me = await account('Rahim');
    const start = await http().get('/api/users/me/reminder-timing').set(auth(me.token)).expect(200);
    expect(start.body.own).toEqual({ repeatMinutes: null, laterMinutes: null, rings: null, familyAlertMinutes: null });
    expect(start.body.effective).toMatchObject({ repeatMinutes: 15, laterMinutes: 15, rings: 4, missedGraceMinutes: 50 });

    const saved = await http().put('/api/users/me/reminder-timing').set(auth(me.token))
      .send({ repeatMinutes: 10, rings: 3, familyAlertMinutes: 30 }).expect(200);
    expect(saved.body.effective).toMatchObject({ repeatMinutes: 10, laterMinutes: 10, rings: 3, missedGraceMinutes: 30 });
    const config = await http().get('/api/app-config').set(auth(me.token)).expect(200);
    expect(config.body.reminders).toMatchObject({ repeatMinutes: 10, rings: 3, missedGraceMinutes: 30, backstopAfterMinutes: 10 });

    // 3 rings 10 min apart: the last ends at 22 min, so 20 is refused.
    const early = await http().put('/api/users/me/reminder-timing').set(auth(me.token)).send({ familyAlertMinutes: 20 }).expect(400);
    expect(early.body.code).toBe('FAMILY_ALERT_TOO_EARLY');
    await http().put('/api/users/me/reminder-timing').set(auth(me.token)).send({ rings: 9 }).expect(400); // out of range
    await http().put('/api/users/me/reminder-timing').set(auth(me.token)).send({ secret: 1 }).expect(400); // unknown field

    const reset = await http().put('/api/users/me/reminder-timing').set(auth(me.token))
      .send({ repeatMinutes: null, rings: null, familyAlertMinutes: null }).expect(200);
    expect(reset.body.effective).toMatchObject({ repeatMinutes: 15, rings: 4, missedGraceMinutes: 50 });
  });

  it("On time / Late follows the patient's own family-alert time, and so does the missed sweep", async () => {
    const me = await account('Rahim');
    const onTime = await dueDose(me, 40);
    await http().post(`/api/medicine-schedule/doses/${onTime}/taken`).set(auth(me.token)).send({}).expect(201);
    expect((await prisma.medicineDose.findUnique({ where: { id: onTime } })).takenLate).toBe(false);

    await http().put('/api/users/me/reminder-timing').set(auth(me.token)).send({ familyAlertMinutes: 60 }).expect(200);
    const stillOnTime = await dueDose(me, 55); // past the .env 50, inside her own 60
    const sweep = app.get(MissedDoseAlertService);
    await sweep.run(new Date());
    expect((await prisma.medicineDose.findUnique({ where: { id: stillOnTime } })).status).toBe('PENDING');
    await http().post(`/api/medicine-schedule/doses/${stillOnTime}/taken`).set(auth(me.token)).send({}).expect(201);
    expect((await prisma.medicineDose.findUnique({ where: { id: stillOnTime } })).takenLate).toBe(false);

    const late = await dueDose(me, 70);
    await sweep.run(new Date());
    expect((await prisma.medicineDose.findUnique({ where: { id: late } })).status).toBe('MISSED');
    await http().post(`/api/medicine-schedule/doses/${late}/taken`).set(auth(me.token)).send({}).expect(201);
    expect(await prisma.medicineDose.findUnique({ where: { id: late } })).toMatchObject({ status: 'TAKEN', takenLate: true });
  });

  it('the caregiver gives a dose and switches easy mode; another member, a stranger or a hidden member: 404', async () => {
    const [mother, carer, brother, stranger] = [await account('Mother'), await account('Carer'), await account('Brother'), await account('Stranger')];
    await family(carer, mother, brother);
    const dose = await dueDose(mother, 5);

    await http().post(`/api/medicine-schedule/doses/${dose}/taken?forUserId=${mother.id}`).set(auth(brother.token)).send({}).expect(404);
    await http().post(`/api/medicine-schedule/doses/${dose}/taken?forUserId=${mother.id}`).set(auth(stranger.token)).send({}).expect(404);
    await http().put(`/api/family/members/${mother.id}/easy-mode`).set(auth(brother.token)).send({ on: true }).expect(404);

    // The caregiver sees the dose id (to give it); the brother doesn't.
    const carerView = await http().get(`/api/family/members/${mother.id}/status`).set(auth(carer.token)).expect(200);
    expect(carerView.body.doses[0]).toMatchObject({ id: dose, givenByCaregiver: false });
    expect(carerView.body.member.easyMode).toBe(false);
    const brotherView = await http().get(`/api/family/members/${mother.id}/status`).set(auth(brother.token)).expect(200);
    expect(brotherView.body.doses[0].id).toBeUndefined();
    expect(brotherView.body.member.easyMode).toBeUndefined();

    const given = await http().post(`/api/medicine-schedule/doses/${dose}/taken?forUserId=${mother.id}`).set(auth(carer.token)).send({}).expect(201);
    expect(given.body).toMatchObject({ status: 'TAKEN', takenById: carer.id, takenLate: false });
    const after = await http().get(`/api/family/members/${mother.id}/status`).set(auth(brother.token)).expect(200);
    expect(after.body.doses[0]).toMatchObject({ status: 'TAKEN', givenByCaregiver: true });
    // Again: nothing changes, no second notice.
    await http().post(`/api/medicine-schedule/doses/${dose}/taken?forUserId=${mother.id}`).set(auth(carer.token)).send({}).expect(201);
    const told = (await prisma.notification.findMany({ where: { userId: mother.id, type: 'SYSTEM' } }))
      .filter((n: any) => n.data?.kind === 'caregiver_action');
    expect(told.map((n: any) => n.data)).toEqual([expect.objectContaining({ action: 'dose_given', doseIds: dose })]);
    expect(await prisma.auditLog.count({ where: { action: 'dose.give', subjectUserId: mother.id } })).toBe(1);

    const on = await http().put(`/api/family/members/${mother.id}/easy-mode`).set(auth(carer.token)).send({ on: true }).expect(200);
    expect(on.body).toEqual({ userId: mother.id, easyMode: true });
    expect((await http().get('/api/users/me').set(auth(mother.token)).expect(200)).body.easyMode).toBe(true);
    // She can turn it off herself.
    await http().patch('/api/users/me').set(auth(mother.token)).send({ easyMode: false }).expect(200);
    expect((await prisma.user.findUnique({ where: { id: mother.id } })).easyMode).toBe(false);

    // Hidden from family: the caregiver can do neither.
    await http().patch('/api/users/me').set(auth(mother.token)).send({ profileVisibleToFamily: false }).expect(200);
    const dose2 = await dueDose(mother, 5);
    await http().post(`/api/medicine-schedule/doses/${dose2}/taken?forUserId=${mother.id}`).set(auth(carer.token)).send({}).expect(404);
    await http().put(`/api/family/members/${mother.id}/easy-mode`).set(auth(carer.token)).send({ on: true }).expect(404);
  });
});
