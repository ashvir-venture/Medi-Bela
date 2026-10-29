import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../app.module';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminAnalyticsService } from '../admin-analytics.service';
import { makeTestPrisma, makeUser, resetDb, signupDetails } from '../../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

d('Admin analytics over HTTP (real AppModule + Postgres)', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(role: 'USER' | 'ADMIN' | 'PHARMACIST', name = role) {
    seq += 1;
    const phone = `+88017200${String(seq).padStart(5, '0')}`;
    const res = await http()
      .post('/api/v1/auth/register')
      .send({
        phone,
        name: `${name} ${seq}`,
        password: 'pass1234',
        ...(await signupDetails(prisma)),
      })
      .expect(201);
    if (role !== 'USER')
      await prisma.user.update({
        where: { id: res.body.user.id },
        data: { role },
      });
    return {
      token: res.body.tokens.accessToken as string,
      id: res.body.user.id as string,
    };
  }

  function prescription(userId: string, status: string, extra: Record<string, unknown> = {}) {
    return prisma.prescription.create({
      data: { userId, imageUrl: 'https://x/y.jpg', status, ...extra },
    });
  }

  function line(prescriptionId: string, medicineId: string, revision = 1) {
    return prisma.prescriptionMedicine.create({
      data: {
        prescriptionId,
        medicineId,
        revision,
        medicineName: 'x',
        dosage: '1',
        frequency: 'daily',
        duration: '7 days',
      },
    });
  }

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
    delete process.env.LLM_API_BASE_URL;
    delete process.env.LLM_API_KEY;
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .compile();
    app = mod.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    app.setGlobalPrefix('api/v1');
    await app.init();
  });
  afterAll(async () => {
    await app.close();
    await prisma.$disconnect();
  });
  beforeEach(async () => {
    await resetDb(prisma);
    await prisma.$executeRawUnsafe('TRUNCATE prescriptions, doctors, medicines, audit_logs CASCADE');
    // Each test starts from fresh numbers, not the previous test's cache.
    (app.get(AdminAnalyticsService) as any).cache.clear();
  });

  it('is ADMIN only', async () => {
    const pharmacist = await account('PHARMACIST');
    const user = await account('USER');
    for (const p of ['', '/divisions/1', '/top-doctors', '/top-medicines']) {
      await http().get(`/api/v1/admin/analytics${p}`).expect(401);
      await http().get(`/api/v1/admin/analytics${p}`).set(auth(pharmacist.token)).expect(403);
      await http().get(`/api/v1/admin/analytics${p}`).set(auth(user.token)).expect(403);
    }
  });

  it('breaks patients down by division, district, gender and age, matching the users table', async () => {
    const admin = await account('ADMIN');
    await account('PHARMACIST');
    const signup: any = await signupDetails(prisma);
    const details = {
      ...signup,
      dateOfBirth: new Date(`${signup.dateOfBirth}T00:00:00Z`),
    };
    await account('USER');
    await account('USER');
    // No details (an account from before Round 6) and a deleted one.
    await makeUser(prisma, 'Old account');
    await makeUser(prisma, 'Gone', { ...details, accountStatus: 'DELETED' });
    // A child: 10 years old.
    const tenYearsAgo = new Date();
    tenYearsAgo.setUTCFullYear(tenYearsAgo.getUTCFullYear() - 10);
    await makeUser(prisma, 'Child', { ...details, dateOfBirth: tenYearsAgo });

    const { body } = await http().get('/api/v1/admin/analytics').set(auth(admin.token)).expect(200);
    expect(body.users.total).toBe(4);
    const division = body.users.byDivision.find((r: any) => r.id === details.divisionId);
    expect(division.count).toBe(3);
    expect(
      body.users.byDivision.reduce((s: number, r: any) => s + r.count, 0) + body.users.divisionNotSet,
    ).toBe(4);
    expect(body.users.divisionNotSet).toBe(1);
    expect(body.users.genderNotSet).toBe(1);
    expect(body.users.byAge).toEqual([
      { band: '0-17', count: 1 },
      { band: '18-39', count: 0 },
      { band: '40-59', count: 0 },
      { band: '60+', count: 2 }, // signupDetails: born 1960
    ]);
    expect(body.users.ageNotSet).toBe(1);
    expect(body.cacheSeconds).toBe(300);

    const districts = await http()
      .get(`/api/v1/admin/analytics/divisions/${details.divisionId}`)
      .set(auth(admin.token))
      .expect(200);
    expect(districts.body.districts.find((r: any) => r.id === details.districtId).count).toBe(3);
    await http().get('/api/v1/admin/analytics/divisions/999999').set(auth(admin.token)).expect(404);
  });

  it('ranks doctors and medicines by distinct patients on confirmed prescriptions only', async () => {
    const admin = await account('ADMIN');
    const [a, b, c] = [await account('USER'), await account('USER'), await account('USER')];
    const popular = await prisma.doctor.create({
      data: { name: 'Dr. Popular' },
    });
    const other = await prisma.doctor.create({ data: { name: 'Dr. Other' } });
    const seclo = await prisma.medicine.create({
      data: { brandName: 'Seclo' },
    });
    const napa = await prisma.medicine.create({ data: { brandName: 'Napa' } });

    // a twice (counts once), b ended, c only pending (not counted).
    const p1 = await prescription(a.id, 'ACTIVE', { doctorId: popular.id });
    const p2 = await prescription(a.id, 'ACTIVE', { doctorId: popular.id });
    const p3 = await prescription(b.id, 'ENDED', { doctorId: popular.id });
    await prescription(c.id, 'AWAITING_CONFIRMATION', { doctorId: other.id });
    const p5 = await prescription(c.id, 'ACTIVE', {
      doctorId: other.id,
      currentRevision: 2,
    });
    await line(p1.id, seclo.id);
    await line(p2.id, seclo.id);
    await line(p3.id, seclo.id);
    await line(p3.id, napa.id);
    await line(p5.id, napa.id, 1); // an old revision: not counted
    await line(p5.id, seclo.id, 2);

    const { body } = await http().get('/api/v1/admin/analytics').set(auth(admin.token)).expect(200);
    expect(body.topDoctors.map((r: any) => [r.name, r.patients])).toEqual([
      ['Dr. Popular', 2],
      ['Dr. Other', 1],
    ]);
    expect(body.topMedicines.map((r: any) => [r.brandName, r.patients])).toEqual([
      ['Seclo', 3],
      ['Napa', 1],
    ]);

    const page = await http().get('/api/v1/admin/analytics/top-doctors').set(auth(admin.token)).expect(200);
    expect(page.body.items.map((r: any) => r.rank)).toEqual([1, 2]);
    expect(page.body.nextCursor).toBeNull();
    await http().get('/api/v1/admin/analytics/top-doctors?cursor=abc').set(auth(admin.token)).expect(400);

    const detail = await http()
      .get(`/api/v1/catalog/medicines/${seclo.id}`)
      .set(auth(admin.token))
      .expect(200);
    expect(detail.body.patients).toBe(3);
  });

  it('counts incomplete records by the new rule; Created by is admin-only and follows the last editor', async () => {
    const admin = await account('ADMIN');
    const p1 = await account('PHARMACIST');
    const p2 = await account('PHARMACIST');
    const specialty = await prisma.doctorSpecialty.findFirst();
    const form = await prisma.medicineForm.findFirst();
    const category = await prisma.medicineCategory.findFirst();
    // Complete without BMDC number or district.
    await prisma.doctor.create({
      data: {
        name: 'Dr. Full',
        specialtyId: specialty.id,
        phone: '01711000000',
        chamber: 'Dhanmondi',
      },
    });
    const partial = await prisma.doctor.create({
      data: {
        name: 'Dr. Partial',
        bmdcNumber: 'A-1',
        specialtyId: specialty.id,
        createdById: p1.id,
      },
    });
    // Complete without a generic name.
    await prisma.medicine.create({
      data: {
        brandName: 'Seclo',
        formId: form.id,
        categoryId: category.id,
        manufacturer: 'Square Pharma',
      },
    });
    await prisma.medicine.create({ data: { brandName: 'Stub' } });

    const { body } = await http().get('/api/v1/admin/analytics').set(auth(admin.token)).expect(200);
    expect(body.catalog).toEqual({
      doctors: 2,
      medicines: 2,
      incompleteDoctors: 1,
      incompleteMedicines: 1,
    });
    const dash = await http().get('/api/v1/pharmacist/dashboard').set(auth(p1.token)).expect(200);
    expect(dash.body.catalog).toEqual({
      incompleteDoctors: 1,
      incompleteMedicines: 1,
    });

    await http()
      .patch(`/api/v1/catalog/doctors/${partial.id}`)
      .set(auth(p2.token))
      .send({ phone: '01711000001' })
      .expect(200);
    const asAdmin = await http()
      .get(`/api/v1/catalog/doctors/${partial.id}`)
      .set(auth(admin.token))
      .expect(200);
    expect(asAdmin.body.createdBy).toMatchObject({
      id: p2.id,
      role: 'PHARMACIST',
    });
    expect(asAdmin.body.incomplete).toBe(true); // still no chamber
    const list = await http()
      .get('/api/v1/catalog/doctors?incomplete=true')
      .set(auth(admin.token))
      .expect(200);
    expect(list.body.items.map((r: any) => r.name)).toEqual(['Dr. Partial']);
    expect(list.body.items[0].createdBy.id).toBe(p2.id);

    const asPharmacist = await http()
      .get(`/api/v1/catalog/doctors/${partial.id}`)
      .set(auth(p1.token))
      .expect(200);
    expect(asPharmacist.body).not.toHaveProperty('createdBy');
    const pharmacistList = await http().get('/api/v1/catalog/doctors').set(auth(p1.token)).expect(200);
    expect(pharmacistList.body.items[0]).not.toHaveProperty('createdBy');
  });
});
