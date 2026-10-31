import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../notifications/push.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { TestReminderJob } from '../health/test-reminder.job';
import { makeTestPrisma, resetDb, signupDetails } from '../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);
const MIN = 60_000;

/**
 * Rounds 12-13 over real HTTP + Postgres: who may do what (patient,
 * caregiver, another member, a stranger), and the numbers (every N days, the
 * taken window, test reminder days, medicine box counts, timings from .env).
 */
d('Rounds 12-13: access and calculations', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(name: string, role: 'USER' | 'PHARMACIST' = 'USER') {
    seq += 1;
    const phone = `017600${String(seq).padStart(5, '0')}`;
    const res = await http()
      .post('/api/auth/register')
      .send({ phone, name, password: 'pass1234', acceptTerms: true, ...(await signupDetails(prisma)) })
      .expect(201);
    if (role !== 'USER') await prisma.user.update({ where: { id: res.body.user.id }, data: { role } });
    return { token: res.body.tokens.accessToken as string, id: res.body.user.id as string, phone };
  }

  /** carer is CAREGIVER; the others are members of the same family. */
  async function family(carer: { token: string }, ...members: { token: string; phone: string }[]) {
    await http().post('/api/family').set(auth(carer.token)).send({ name: 'Home' }).expect(201);
    for (const m of members) {
      const inv = await http().post('/api/family/invitations').set(auth(carer.token)).send({ phone: m.phone }).expect(201);
      await http().post(`/api/family/invitations/${inv.body.id}/accept`).set(auth(m.token)).expect(201);
    }
  }

  async function sentPrescription(patient: { token: string }, pharmacist: { token: string }) {
    const up = await http().post('/api/prescriptions').set(auth(patient.token))
      .attach('image', JPEG, { filename: 'rx.jpg', contentType: 'image/jpeg' }).expect(201);
    const id = up.body.id as string;
    const form = (await prisma.medicineForm.findFirst()) ?? (await prisma.medicineForm.create({ data: { name: 'Tablet' } }));
    const meal = (await prisma.mealTiming.findFirst()) ?? (await prisma.mealTiming.create({ data: { name: 'Before meal' } }));
    const cbc = await http().post('/api/catalog/tests').set(auth(pharmacist.token)).send({ name: `CBC ${seq}` }).expect(201);
    await http().put(`/api/prescriptions/admin/${id}/details`).set(auth(pharmacist.token)).send({
      tests: [{ testId: cbc.body.id, time: '07:30', mealTimingId: meal.id, note: 'fasting' }],
    }).expect(200);
    await http().put(`/api/prescriptions/admin/${id}/medicines`).set(auth(pharmacist.token)).send({
      medicines: [
        { medicineName: 'Napa', dosage: '500 mg, 2 tablets', frequency: '2 times a day', duration: '10 days',
          doseAmount: '2 tablets', formId: form.id, timesPerDay: 2, scheduleTimes: ['08:00', '14:00'], durationDays: 10 },
        { medicineName: 'Vitamin D', dosage: '1 capsule', frequency: '1 time every 7 days', duration: '28 days',
          timesPerDay: 1, scheduleTimes: ['08:00'], durationDays: 28, intervalDays: 7 },
      ],
    }).expect(200);
    const sent = await http().post(`/api/prescriptions/admin/${id}/complete`).set(auth(pharmacist.token)).expect(201);
    return { id, lines: sent.body.medicines as { id: string; medicineName: string; formId: number; intervalDays: number }[], formId: form.id };
  }

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(PushService).useValue({ isEnabled: () => false, send: jest.fn(async () => []) })
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
    await prisma.$executeRawUnsafe('TRUNCATE prescriptions, audit_logs, diagnostic_tests CASCADE');
  });

  it('app-config: signed-in only, and it follows .env', async () => {
    await http().get('/api/app-config').expect(401);
    const u = await account('Rahim');
    const before = await http().get('/api/app-config').set(auth(u.token)).expect(200);
    expect(before.body.reminders).toMatchObject({
      repeatMinutes: 15,
      rings: 4,
      missedGraceMinutes: Number(process.env.DOSE_MISSED_GRACE_MINUTES || 50),
    });
    process.env.REMINDER_REPEAT_MINUTES = '10';
    try {
      const after = await http().get('/api/app-config').set(auth(u.token)).expect(200);
      expect(after.body.reminders).toMatchObject({ repeatMinutes: 10, backstopAfterMinutes: 10 });
    } finally {
      delete process.env.REMINDER_REPEAT_MINUTES;
    }
  });

  it('prescription: form + every N days; caregiver told; request edit by patient or caregiver only', async () => {
    const [mother, carer, brother, stranger] = [await account('Mother'), await account('Carer'), await account('Brother'), await account('Stranger')];
    const pharmacist = await account('Pharma', 'PHARMACIST');
    await family(carer, mother, brother);

    const rx = await sentPrescription(mother, pharmacist);
    expect(rx.lines.find((l) => l.medicineName === 'Napa')!.formId).toBe(rx.formId);
    expect(rx.lines.find((l) => l.medicineName === 'Vitamin D')!.intervalDays).toBe(7);
    // The caregiver hears it is ready (not the brother, not the stranger).
    const ready = await prisma.notification.findMany({ where: { type: 'PRESCRIPTION_UPDATE', userId: { not: mother.id } } });
    expect(ready.map((n: any) => n.userId)).toEqual([carer.id]);

    // Request edit: a stranger or another member can't; the caregiver can.
    await http().post(`/api/prescriptions/${rx.id}/request-edit`).set(auth(stranger.token)).send({ note: 'change it' }).expect(404);
    await http().post(`/api/prescriptions/${rx.id}/request-edit?forUserId=${mother.id}`).set(auth(brother.token)).send({ note: 'change it' }).expect(404);
    await http().post(`/api/prescriptions/${rx.id}/request-edit`).set(auth(mother.token)).send({ note: 'x' }).expect(400); // too short
    const asked = await http().post(`/api/prescriptions/${rx.id}/request-edit?forUserId=${mother.id}`).set(auth(carer.token))
      .send({ note: 'Night dose at 10 PM please' }).expect(201);
    expect(asked.body.status).toBe('PENDING');
    const queue = await http().get('/api/prescriptions/admin/queue?status=PENDING').set(auth(pharmacist.token)).expect(200);
    expect(queue.body.items[0].editRequestNote).toBe('Night dose at 10 PM please');
    // Patients can't read the pharmacist queue.
    await http().get('/api/prescriptions/admin/queue').set(auth(mother.token)).expect(403);
    // Sending it again clears the note.
    const again = await http().post(`/api/prescriptions/admin/${rx.id}/complete`).set(auth(pharmacist.token)).expect(201);
    expect(again.body.editRequestNote).toBeNull();
  });

  it('confirm: every-7-days doses start tomorrow; tests become reminders; taken only inside its window', async () => {
    const mother = await account('Mother');
    const pharmacist = await account('Pharma', 'PHARMACIST');
    const rx = await sentPrescription(mother, pharmacist);
    await http().post(`/api/prescriptions/${rx.id}/confirm`).set(auth(mother.token)).send({}).expect(201);

    const vitD = await prisma.medicineRoutine.findFirst({ where: { userId: mother.id, medicineName: 'Vitamin D' }, include: { doses: { orderBy: { scheduledAt: 'asc' } } } });
    expect(vitD.intervalDays).toBe(7);
    const gaps = vitD.doses.slice(1).map((dose: any, i: number) => (dose.scheduledAt - vitD.doses[i].scheduledAt) / (24 * 60 * MIN));
    expect(gaps.every((g: number) => g === 7)).toBe(true);
    expect(vitD.doses[0].scheduledAt.getTime()).toBeGreaterThan(Date.now()); // starts the day after confirming

    const test = await prisma.healthReminder.findFirst({ where: { userId: mother.id, testId: { not: null } } });
    expect(test).toMatchObject({ description: 'fasting', status: 'PENDING' });
    // Done can't come before its time.
    await http().post(`/api/health-reminders/${test.id}/complete`).set(auth(mother.token)).send({}).expect(409);

    // Taken window: upcoming = 409; due = 201; past 1 h before the next dose = 409.
    const napa = await prisma.medicineRoutine.findFirst({ where: { userId: mother.id, medicineName: 'Napa' }, include: { doses: { orderBy: { scheduledAt: 'asc' } } } });
    const [first, second] = napa.doses;
    const early = await http().post(`/api/medicine-schedule/doses/${first.id}/taken`).set(auth(mother.token)).send({}).expect(409);
    expect(early.body.code).toBe('DOSE_NOT_DUE');
    await prisma.medicineDose.update({ where: { id: first.id }, data: { scheduledAt: new Date(Date.now() - 10 * MIN) } });
    await prisma.medicineDose.update({ where: { id: second.id }, data: { scheduledAt: new Date(Date.now() + 2 * 60 * MIN) } });
    await http().post(`/api/medicine-schedule/doses/${first.id}/taken`).set(auth(mother.token)).send({}).expect(201);
    const third = napa.doses[2];
    await prisma.medicineDose.update({ where: { id: third.id }, data: { scheduledAt: new Date(Date.now() - 5 * 60 * MIN) } });
    // second (in 2 h) is now the next one after third, which closed 1 h before it... third's window:
    const late = await http().post(`/api/medicine-schedule/doses/${third.id}/taken`).set(auth(mother.token))
      .send({ takenAt: new Date(Date.now() + 90 * MIN).toISOString() }).expect(409);
    expect(late.body.code).toBe('DOSE_WINDOW_CLOSED');
  });

  it('test reminder: the caregiver is told on the last day, nobody else', async () => {
    const [mother, carer, brother] = [await account('Mother'), await account('Carer'), await account('Brother')];
    await family(carer, mother, brother);
    const rx = await sentPrescription(mother, await account('Pharma', 'PHARMACIST'));
    await http().post(`/api/prescriptions/${rx.id}/confirm`).set(auth(mother.token)).send({}).expect(201);
    const test = await prisma.healthReminder.findFirst({ where: { userId: mother.id, testId: { not: null } } });
    await prisma.healthReminder.update({ where: { id: test.id }, data: { scheduledAt: new Date(Date.now() - 2 * 24 * 60 * MIN - MIN) } });

    const job = app.get(TestReminderJob);
    expect((await job.run()).alerted).toBe(1);
    expect((await job.run()).alerted).toBe(0); // once
    const alerts = await prisma.notification.findMany({ where: { relatedEntityId: `test:${test.id}` } });
    expect(alerts.map((n: any) => n.userId)).toEqual([carer.id]);
    expect(JSON.stringify(alerts)).not.toMatch(/CBC/);
  });

  it('personal reminders: own, caregiver for a member; others get 404; Later tells the caregiver', async () => {
    const [mother, carer, brother, stranger] = [await account('Mother'), await account('Carer'), await account('Brother'), await account('Stranger')];
    await family(carer, mother, brother);
    const body = { name: 'walk', description: '30 minutes', scheduleTimes: ['07:00', '18:00'], intervalDays: 2 };

    const own = await http().post('/api/personal-reminders').set(auth(mother.token)).send(body).expect(201);
    expect(own.body.byCaregiver).toBe(false);
    await http().post('/api/personal-reminders').set(auth(mother.token)).send({ ...body, scheduleTimes: ['7am'] }).expect(400);
    await http().patch(`/api/personal-reminders/${own.body.id}`).set(auth(stranger.token)).send({ name: 'x' }).expect(404);
    await http().delete(`/api/personal-reminders/${own.body.id}`).set(auth(carer.token)).expect(404); // no forUserId: not theirs
    await http().get(`/api/personal-reminders?forUserId=${mother.id}`).set(auth(brother.token)).expect(404); // a member is no caregiver
    await http().get(`/api/personal-reminders?forUserId=${mother.id}`).set(auth(stranger.token)).expect(404);

    const set = await http().post(`/api/personal-reminders?forUserId=${mother.id}`).set(auth(carer.token)).send(body).expect(201);
    expect(set.body.byCaregiver).toBe(true);
    const list = await http().get('/api/personal-reminders').set(auth(mother.token)).expect(200);
    expect(list.body).toHaveLength(2);

    // Later on her own: nobody told. On the caregiver's: the caregiver, once per ring.
    expect((await http().post(`/api/personal-reminders/${own.body.id}/later`).set(auth(mother.token)).send({}).expect(201)).body.notified).toBe(false);
    const at = new Date().toISOString();
    expect((await http().post(`/api/personal-reminders/${set.body.id}/later`).set(auth(mother.token)).send({ at }).expect(201)).body.notified).toBe(true);
    await http().post(`/api/personal-reminders/${set.body.id}/later`).set(auth(mother.token)).send({ at }).expect(201);
    expect(await prisma.notification.count({ where: { userId: carer.id, relatedEntityId: { startsWith: 'prlater:' } } })).toBe(1);
    await http().post(`/api/personal-reminders/${set.body.id}/later`).set(auth(carer.token)).send({}).expect(404); // only the member

    // Hidden from family: the caregiver can no longer act.
    await prisma.user.update({ where: { id: mother.id }, data: { profileVisibleToFamily: false } });
    await http().get(`/api/personal-reminders?forUserId=${mother.id}`).set(auth(carer.token)).expect(404);
  });

  it('medicine box: counts down by taken doses x units per dose; others 404; Ignore tells the caregiver', async () => {
    const [mother, carer, stranger] = [await account('Mother'), await account('Carer'), await account('Stranger')];
    await family(carer, mother);
    const rx = await sentPrescription(mother, await account('Pharma', 'PHARMACIST'));
    await http().post(`/api/prescriptions/${rx.id}/confirm`).set(auth(mother.token)).send({}).expect(201);
    const napa = await prisma.medicineRoutine.findFirst({ where: { userId: mother.id, medicineName: 'Napa' }, include: { doses: { orderBy: { scheduledAt: 'asc' } } } });

    const empty = await http().get('/api/medicine-box').set(auth(mother.token)).expect(200);
    expect(empty.body.startedAt).toBeNull();
    expect(empty.body.items.every((i: any) => i.quantity === null)).toBe(true);

    // Nobody else can count her medicine, a stranger not even with forUserId.
    await http().put('/api/medicine-box').set(auth(stranger.token)).send({ items: [{ routineId: napa.id, quantity: 5 }] }).expect(404);
    await http().put(`/api/medicine-box?forUserId=${mother.id}`).set(auth(stranger.token)).send({ items: [{ routineId: napa.id, quantity: 5 }] }).expect(404);
    await http().put('/api/medicine-box').set(auth(mother.token)).send({ items: [{ routineId: napa.id, quantity: -1 }] }).expect(400);

    const started = await http().put('/api/medicine-box').set(auth(mother.token)).send({ items: [{ routineId: napa.id, quantity: 10 }] }).expect(200);
    expect(started.body.startedAt).not.toBeNull();

    // Two doses taken ("2 tablets" each): 10 - 4 = 6 left, 3 doses.
    for (const dose of napa.doses.slice(0, 2)) {
      await prisma.medicineDose.update({ where: { id: dose.id }, data: { status: 'TAKEN', takenAt: new Date() } });
    }
    await new Promise((r) => setTimeout(r, 20)); // the refill below counts from after these
    const box = await http().get('/api/medicine-box').set(auth(mother.token)).expect(200);
    expect(box.body.items.find((i: any) => i.routineId === napa.id)).toMatchObject({ unitsPerDose: 2, quantity: 10, remaining: 6, dosesLeft: 3 });

    // The caregiver sees and refills it; the count starts again from now.
    const seen = await http().get(`/api/medicine-box?forUserId=${mother.id}`).set(auth(carer.token)).expect(200);
    expect(seen.body.items.find((i: any) => i.routineId === napa.id).remaining).toBe(6);
    await http().put(`/api/medicine-box?forUserId=${mother.id}`).set(auth(carer.token)).send({ items: [{ routineId: napa.id, quantity: 30 }] }).expect(200);
    const refilled = await http().get('/api/medicine-box').set(auth(mother.token)).expect(200);
    expect(refilled.body.items.find((i: any) => i.routineId === napa.id)).toMatchObject({ quantity: 30, remaining: 30 });

    // Ignore: the member only; the caregiver gets one banner per count.
    await http().post(`/api/medicine-box/${napa.id}/ignore`).set(auth(stranger.token)).expect(404);
    expect((await http().post(`/api/medicine-box/${napa.id}/ignore`).set(auth(mother.token)).expect(201)).body.notified).toBe(true);
    await http().post(`/api/medicine-box/${napa.id}/ignore`).set(auth(mother.token)).expect(201);
    const told = await prisma.notification.findMany({ where: { userId: carer.id, relatedEntityId: { startsWith: 'stock:' } } });
    expect(told).toHaveLength(1);
    expect(told[0].body).not.toMatch(/Napa/);
  });
});
