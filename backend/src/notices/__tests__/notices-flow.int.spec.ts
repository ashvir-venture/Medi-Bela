import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../app.module';
import { PrismaService } from '../../prisma/prisma.service';
import { PushService } from '../../notifications/push.service';
import { NoticesService } from '../notices.service';
import { makeTestPrisma, resetDb, signupDetails } from '../../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

/** Round 7 over HTTP + Postgres: approval, send-back note, scheduling, divisions. */
d('Notices: approval, scheduling and divisions', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  let seq = 0;

  async function account(role: 'USER' | 'ADMIN' | 'PHARMACIST', divisionId?: number) {
    seq += 1;
    const phone = `+88017500${String(seq).padStart(5, '0')}`;
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ phone, name: `${role} ${seq}`, password: 'pass1234', ...(await signupDetails(prisma)) })
      .expect(201);
    const data: Record<string, unknown> = { role };
    // A division alone (the lower levels cleared) keeps the address chain valid.
    if (divisionId !== undefined) Object.assign(data, { divisionId, districtId: null, upazilaId: null });
    await prisma.user.update({ where: { id: res.body.user.id }, data });
    return { token: res.body.tokens.accessToken as string, id: res.body.user.id as string };
  }

  const mine = async (token: string) =>
    (await http().get('/api/v1/notices/mine').set(auth(token)).expect(200)).body.map((n: any) => n.title);
  const pushes = (noticeId: string) => prisma.notification.count({ where: { type: 'NOTICE', relatedEntityId: noticeId } });

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma)
      .overrideProvider(PushService).useValue({ isEnabled: () => false, send: jest.fn(async () => []) })
      .compile();
    app = mod.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, transformOptions: { enableImplicitConversion: true } }));
    app.setGlobalPrefix('api/v1');
    await app.init();
  });
  afterAll(async () => { await app.close(); await prisma.$disconnect(); });
  beforeEach(async () => {
    await resetDb(prisma);
    await prisma.$executeRawUnsafe('TRUNCATE notices, audit_logs CASCADE');
  });

  it('pharmacist drafts and submits; admin sends back with a note, then approves; pharmacist is locked out after', async () => {
    const pharmacist = await account('PHARMACIST');
    const admin = await account('ADMIN');
    const patient = await account('USER');

    const n = (await http().post('/api/v1/admin/notices').set(auth(pharmacist.token))
      .send({ title: 'Dengue alert', content: 'Use mosquito nets.', source: 'DGHS', sourceUrl: 'https://dghs.gov.bd' }).expect(201)).body;
    expect(n).toMatchObject({ status: 'DRAFT', source: 'DGHS' });
    await http().post('/api/v1/admin/notices').set(auth(pharmacist.token)).send({ title: 't', content: 'c', sourceUrl: 'http://x.test' }).expect(400);
    await http().post(`/api/v1/admin/notices/${n.id}/publish`).set(auth(pharmacist.token)).expect(403);

    const at = (path: string, token = pharmacist.token) => http().post(`/api/v1/admin/notices/${n.id}/${path}`).set(auth(token));
    await at('submit').expect(201);
    await http().patch(`/api/v1/admin/notices/${n.id}`).set(auth(pharmacist.token)).send({ title: 'x' }).expect(403);   // locked while pending
    await at('withdraw').expect(201);
    await http().patch(`/api/v1/admin/notices/${n.id}`).set(auth(pharmacist.token)).send({ title: 'Dengue: use nets' }).expect(200);
    await at('submit').expect(201);

    await at('send-back', admin.token).send({}).expect(400);                                   // the note is required
    const back = (await at('send-back', admin.token).send({ note: 'Add the hotline number.' }).expect(201)).body;
    expect(back).toMatchObject({ status: 'DRAFT', reviewNote: 'Add the hotline number.' });
    await at('submit').expect(201);
    expect((await http().get(`/api/v1/admin/notices/${n.id}`).set(auth(admin.token)).expect(200)).body.reviewNote).toBeNull();

    expect(await mine(patient.token)).toEqual([]);
    const approved = (await at('publish', admin.token).expect(201)).body;
    expect(approved).toMatchObject({ status: 'PUBLISHED', approvedBy: { id: admin.id } });
    expect(await mine(patient.token)).toEqual(['Dengue: use nets']);
    expect(await pushes(n.id)).toBeGreaterThanOrEqual(1);
    const shown = (await http().get('/api/v1/notices/mine').set(auth(patient.token))).body[0];
    expect(shown).toMatchObject({ source: 'DGHS' });
    expect(shown).not.toHaveProperty('reviewNote');

    await http().patch(`/api/v1/admin/notices/${n.id}`).set(auth(pharmacist.token)).send({ title: 'x' }).expect(403);
    await http().delete(`/api/v1/admin/notices/${n.id}`).set(auth(pharmacist.token)).expect(403);
    await at('archive').expect(403);
    expect(await prisma.auditLog.count({ where: { entityId: n.id, action: 'notice.approve' } })).toBe(1);
  });

  it('a scheduled notice stays hidden and unpushed until its start time, then goes live once', async () => {
    const admin = await account('ADMIN');
    const patient = await account('USER');
    const startsAt = new Date(Date.now() + 3_600_000);
    const n = (await http().post('/api/v1/admin/notices').set(auth(admin.token))
      .send({ title: 'Vaccine camp', content: 'Saturday', startsAt: startsAt.toISOString() }).expect(201)).body;
    const published = (await http().post(`/api/v1/admin/notices/${n.id}/publish`).set(auth(admin.token)).expect(201)).body;
    expect(published).toMatchObject({ status: 'PUBLISHED', publishedAt: null });
    expect(await mine(patient.token)).toEqual([]);
    expect(await pushes(n.id)).toBe(0);

    const notices = app.get(NoticesService);
    expect(await notices.goLive(new Date())).toBe(0);                                   // not yet
    const later = new Date(startsAt.getTime() + 60_000);
    expect(await Promise.all([notices.goLive(later), notices.goLive(later)])).toEqual(expect.arrayContaining([1, 0]));
    expect(await pushes(n.id)).toBeGreaterThanOrEqual(1);
    const pushed = await pushes(n.id);
    expect(await notices.goLive(later)).toBe(0);
    expect(await pushes(n.id)).toBe(pushed);                                           // pushed once
  });

  it('division notices reach (list and push) only that division; nationwide ones reach everyone', async () => {
    const [a, b] = await prisma.division.findMany({ orderBy: { id: 'asc' }, take: 2 });
    const admin = await account('ADMIN');
    const inA = await account('USER', a.id);
    const inB = await account('USER', b.id);

    const local = (await http().post('/api/v1/admin/notices').set(auth(admin.token))
      .send({ title: 'Local', content: 'c', divisionIds: [a.id] }).expect(201)).body;
    const national = (await http().post('/api/v1/admin/notices').set(auth(admin.token))
      .send({ title: 'National', content: 'c' }).expect(201)).body;
    await http().post('/api/v1/admin/notices').set(auth(admin.token)).send({ title: 'x', content: 'c', divisionIds: [999999] }).expect(400);
    for (const n of [local, national]) {
      await http().post(`/api/v1/admin/notices/${n.id}/publish`).set(auth(admin.token)).expect(201);
    }

    expect((await mine(inA.token)).sort()).toEqual(['Local', 'National']);
    expect(await mine(inB.token)).toEqual(['National']);
    const localPushes = await prisma.notification.findMany({ where: { relatedEntityId: local.id }, select: { userId: true } });
    const reached = localPushes.map((p: any) => p.userId);
    expect(reached).toContain(inA.id);
    expect(reached).not.toContain(inB.id);
  });
});
