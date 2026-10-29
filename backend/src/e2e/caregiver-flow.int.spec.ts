import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../notifications/push.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { makeTestPrisma, resetDb, signupDetails } from '../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);

/**
 * Round 6 over real HTTP + Postgres: required signup details, the
 * caregiver acting for a member (upload, confirm with edits, mark taken,
 * manage routines), and the patient's own routine create/edit/remove.
 */
d('Round 6: confirm, routines and caregiver actions', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(role: 'USER' | 'PHARMACIST', name: string, extra: Record<string, unknown> = {}) {
    seq += 1;
    const phone = `+88017400${String(seq).padStart(5, '0')}`;
    const res = await http()
      .post('/api/auth/register')
      .send({ phone, name, password: 'pass1234', ...(await signupDetails(prisma)) })
      .expect(201);
    if (role !== 'USER' || Object.keys(extra).length) {
      await prisma.user.update({ where: { id: res.body.user.id }, data: { role, ...extra } });
    }
    return { token: res.body.tokens.accessToken as string, id: res.body.user.id as string, phone };
  }

  async function family(caregiver: { token: string }, ...members: { token: string; phone: string }[]) {
    await http().post('/api/family').set(auth(caregiver.token)).send({ name: 'Home' }).expect(201);
    for (const m of members) {
      const inv = await http().post('/api/family/invitations').set(auth(caregiver.token)).send({ phone: m.phone }).expect(201);
      await http().post(`/api/family/invitations/${inv.body.id}/accept`).set(auth(m.token)).expect(201);
    }
  }

  /** Upload (optionally by the caregiver), then a pharmacist prepares two lines and sends it. */
  async function preparedPrescription(uploader: { token: string }, pharmacist: { token: string }, forUserId?: string) {
    const qs = forUserId ? `?forUserId=${forUserId}` : '';
    const up = await http().post(`/api/prescriptions${qs}`).set(auth(uploader.token))
      .attach('image', JPEG, { filename: 'rx.jpg', contentType: 'image/jpeg' }).expect(201);
    const id = up.body.id as string;
    await http().put(`/api/prescriptions/admin/${id}/medicines`).set(auth(pharmacist.token)).send({
      medicines: [
        { medicineName: 'Metformin', dosage: '500 mg', frequency: '2 times a day', duration: '10 days',
          timesPerDay: 2, scheduleTimes: ['08:00', '20:00'], durationDays: 10 },
        { medicineName: 'Atorva', dosage: '10 mg', frequency: '1 time a day', duration: 'Continuous',
          timesPerDay: 1, scheduleTimes: ['22:00'], continuous: true },
      ],
    }).expect(200);
    const sent = await http().post(`/api/prescriptions/admin/${id}/complete`).set(auth(pharmacist.token)).expect(201);
    expect(sent.body.status).toBe('AWAITING_CONFIRMATION');
    return { id, lines: sent.body.medicines as { id: string; medicineName: string }[] };
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
    await prisma.$executeRawUnsafe('TRUNCATE prescriptions, audit_logs CASCADE');
  });

  it('registration requires the new details and checks the address chain; dropdown data is public', async () => {
    const details = await signupDetails(prisma);
    await http().get('/api/lookups').expect(200);
    const base = { phone: '+8801741000001', name: 'New User', password: 'pass1234' };
    await http().post('/api/auth/register').send(base).expect(400);
    const otherDistrict = await prisma.district.findFirst({ where: { id: { not: details.districtId as number } } });
    if (otherDistrict) {
      await http().post('/api/auth/register').send({ ...base, ...details, districtId: otherDistrict.id }).expect(400);
    }
    await http().post('/api/auth/register').send({ ...base, ...details, dateOfBirth: '2999-01-01' }).expect(400);
    const ok = await http().post('/api/auth/register').send({ ...base, ...details }).expect(201);
    expect(ok.body.user).toMatchObject({ genderId: details.genderId, upazilaId: details.upazilaId });

    // "Edit your details": the address changes as a whole.
    await http().patch('/api/users/me').set(auth(ok.body.tokens.accessToken)).send({ districtId: details.districtId }).expect(400);
    await http().patch('/api/users/me').set(auth(ok.body.tokens.accessToken)).send({ dateOfBirth: '1970-01-02' }).expect(200);
  });

  it('a caregiver uploads and confirms with edits for a member, but never marks her doses; the member is told', async () => {
    const pharmacist = await account('PHARMACIST', 'Pharma');
    const carer = await account('USER', 'Carer');
    const mother = await account('USER', 'Mother');
    await family(carer, mother);
    expect((await prisma.familyMember.findUnique({ where: { userId: carer.id } })).role).toBe('CAREGIVER');

    const rx = await preparedPrescription(carer, pharmacist, mother.id);
    const asMother = await http().get(`/api/prescriptions/${rx.id}`).set(auth(mother.token)).expect(200);
    expect(asMother.body.uploadedByCaregiver).toBe(true);
    expect(asMother.body).not.toHaveProperty('uploadedById');

    const [metformin, atorva] = rx.lines;
    const confirm = (body: object, token = carer.token) =>
      http().post(`/api/prescriptions/${rx.id}/confirm?forUserId=${mother.id}`).set(auth(token)).send(body);
    await confirm({ lines: [{ id: metformin.id, scheduleTimes: ['09:00'] }] }).expect(400);                // count must match
    await confirm({ lines: [{ id: metformin.id, remove: true }, { id: atorva.id, remove: true }] }).expect(400);
    await confirm({ lines: [{ id: metformin.id, startDate: '2000-01-01' }] }).expect(400);                 // not in the past
    await confirm({ lines: [{ id: metformin.id, doseAmount: '2 tablets' }] }).expect(400);                 // not editable
    const done = await confirm({ lines: [{ id: metformin.id, scheduleTimes: ['09:00', '21:00'] }, { id: atorva.id, remove: true }] }).expect(201);
    expect(done.body).toMatchObject({ status: 'ACTIVE', confirmedByCaregiver: true });
    expect(done.body.medicines.map((m: any) => m.medicineName)).toEqual(['Metformin']);
    await confirm({}).expect(409);

    const routines = (await http().get(`/api/medicine-schedule/routines?forUserId=${mother.id}`).set(auth(carer.token)).expect(200)).body;
    expect(routines).toHaveLength(1);
    expect(routines[0]).toMatchObject({ medicineName: 'Metformin', selfAdded: false, editedBy: 'CAREGIVER', scheduleTimes: '["09:00","21:00"]' });
    const motherView = (await http().get('/api/medicine-schedule/routines').set(auth(mother.token)).expect(200)).body;
    expect(motherView[0].editedBy).toBe('CAREGIVER');

    // Only she can mark her doses taken: the caregiver can't, with or without forUserId.
    const dose = await prisma.medicineDose.findFirst({ where: { userId: mother.id }, orderBy: { scheduledAt: 'asc' } });
    await http().post(`/api/medicine-schedule/doses/${dose.id}/taken?forUserId=${mother.id}`).set(auth(carer.token)).send({}).expect(404);
    await http().post(`/api/medicine-schedule/doses/${dose.id}/taken`).set(auth(carer.token)).send({}).expect(404);
    expect((await prisma.medicineDose.findUnique({ where: { id: dose.id } })).status).toBe('PENDING');
    await http().post(`/api/medicine-schedule/doses/${dose.id}/taken`).set(auth(mother.token)).send({}).expect(201);

    const notes = await prisma.notification.findMany({ where: { userId: mother.id, type: 'SYSTEM' } });
    const actions = notes.map((n: any) => n.data.action).sort();
    expect(actions).toEqual(['prescription_confirmed', 'prescription_uploaded']);
    expect(JSON.stringify(notes)).not.toMatch(/Metformin/);
  });

  it('only the caregiver may act for a member, and never for a hidden one', async () => {
    const carer = await account('USER', 'Carer');
    const son = await account('USER', 'Son');
    const hidden = await account('USER', 'Hidden', { profileVisibleToFamily: false });
    const stranger = await account('USER', 'Stranger');
    await family(carer, son, hidden);

    await http().get(`/api/medicine-schedule/routines?forUserId=${son.id}`).set(auth(carer.token)).expect(200);
    await http().get(`/api/medicine-schedule/routines?forUserId=${hidden.id}`).set(auth(carer.token)).expect(404);
    await http().get(`/api/medicine-schedule/routines?forUserId=${carer.id}`).set(auth(son.token)).expect(404);     // members aren't caregivers
    await http().get(`/api/prescriptions/mine?forUserId=${son.id}`).set(auth(stranger.token)).expect(404);
    await http().get('/api/prescriptions/mine?forUserId=not-a-uuid').set(auth(carer.token)).expect(400);
  });

  it('a patient adds, edits and removes their own medicine; pharmacist medicines allow only times and meal timing', async () => {
    const pharmacist = await account('PHARMACIST', 'Pharma');
    const me = await account('USER', 'Me');
    await http().get('/api/catalog/medicines/search?q=na').set(auth(me.token)).expect(200);

    const add = await http().post('/api/medicine-schedule/routines').set(auth(me.token)).send({
      medicineName: 'Vitamin D', strength: '1000 IU', doseAmount: '1 capsule', timesPerDay: 1, scheduleTimes: ['08:00'], durationDays: 30,
    }).expect(201);
    expect(add.body).toMatchObject({ selfAdded: true, addedBy: 'YOU', editedBy: null, dosage: '1000 IU, 1 capsule' });
    expect(await prisma.medicine.count({ where: { brandName: 'Vitamin D' } })).toBe(1);                   // catalog stub
    expect(await prisma.medicineDose.count({ where: { routineId: add.body.id } })).toBeGreaterThan(0);
    await http().post('/api/medicine-schedule/routines').set(auth(me.token)).send({
      medicineName: 'X', timesPerDay: 2, scheduleTimes: ['08:00'], durationDays: 3,
    }).expect(400);

    const edited = await http().patch(`/api/medicine-schedule/routines/${add.body.id}`).set(auth(me.token))
      .send({ timesPerDay: 2, scheduleTimes: ['07:00', '19:00'] }).expect(200);
    expect(edited.body.editedBy).toBe('YOU');
    const future = await prisma.medicineDose.findMany({ where: { routineId: add.body.id, scheduledAt: { gte: new Date() }, status: 'PENDING' } });
    const hhmm = new Set(future.map((x: any) => new Date(x.scheduledAt.getTime() + 6 * 3_600_000).toISOString().slice(11, 16)));
    expect([...hhmm].sort()).toEqual(['07:00', '19:00']);

    // A pharmacist's medicine: times yes, strength no.
    const rx = await preparedPrescription(me, pharmacist);
    await http().post(`/api/prescriptions/${rx.id}/confirm`).set(auth(me.token)).send({}).expect(201);
    const fromRx = (await http().get('/api/medicine-schedule/routines').set(auth(me.token)).expect(200)).body
      .find((r: any) => r.medicineName === 'Metformin');
    await http().patch(`/api/medicine-schedule/routines/${fromRx.id}`).set(auth(me.token)).send({ strength: '1000 mg' }).expect(400);
    await http().patch(`/api/medicine-schedule/routines/${fromRx.id}`).set(auth(me.token)).send({ scheduleTimes: ['10:00', '22:00'] }).expect(200);

    await http().delete(`/api/medicine-schedule/routines/${add.body.id}`).set(auth(me.token)).expect(200);
    expect(await prisma.medicineDose.count({ where: { routineId: add.body.id, status: 'PENDING', scheduledAt: { gte: new Date() } } })).toBe(0);
    const left = (await http().get('/api/medicine-schedule/routines').set(auth(me.token)).expect(200)).body;
    expect(left.map((r: any) => r.medicineName).sort()).toEqual(['Atorva', 'Metformin']);
    expect(await prisma.auditLog.count({ where: { action: { startsWith: 'routine.' }, actorId: me.id } })).toBe(4);
  });
});
