import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { NoticeStatus, NotificationType } from '@prisma/client';
import { AppModule } from '../app.module';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../notifications/push.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { makeTestPrisma, resetDb, signupDetails } from '../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

/**
 * Round 17 over real HTTP + Postgres: sharing a notice with the family and
 * the caregiver change history (both sides, who may read it).
 */
d('Round 17: share a notice, change history', () => {
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

  async function liveNotice(divisionId?: number) {
    return prisma.notice.create({
      data: {
        title: 'Dengue alert',
        content: 'Keep water containers covered.',
        status: NoticeStatus.PUBLISHED,
        publishedAt: new Date(Date.now() - 60_000),
        ...(divisionId ? { divisions: { create: [{ divisionId }] } } : {}),
      },
    });
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
    await resetDb(prisma);
    await prisma.$executeRawUnsafe('TRUNCATE audit_logs, notices CASCADE');
  });

  it('shares a notice with every other visible member, once per sharer', async () => {
    const carer = await account('Rafi');
    const mother = await account('Amma');
    const hidden = await account('Chacha');
    await family(carer, mother, hidden);
    await prisma.user.update({ where: { id: hidden.id }, data: { profileVisibleToFamily: false } });
    const notice = await liveNotice();

    const first = await http().post(`/api/notices/${notice.id}/share-family`).set(auth(mother.token)).expect(201);
    expect(first.body).toEqual({ sharedWith: 1, alreadyShared: false });
    const again = await http().post(`/api/notices/${notice.id}/share-family`).set(auth(mother.token)).expect(201);
    expect(again.body.alreadyShared).toBe(true);

    const rows = await prisma.notification.findMany({ where: { type: NotificationType.SYSTEM, data: { path: ['kind'], equals: 'notice_shared' } } });
    expect(rows.map((r) => r.userId)).toEqual([carer.id]);
    expect(rows[0].title).toContain('Amma');
    expect(rows[0].data).toEqual({ kind: 'notice_shared', noticeId: notice.id });
  });

  it('a recipient opens a shared notice outside their division; others cannot', async () => {
    const carer = await account('Rafi');
    const mother = await account('Amma');
    const stranger = await account('Other');
    await family(carer, mother);
    const otherDivision = await prisma.division.findFirst({
      where: { id: { not: (await prisma.user.findUniqueOrThrow({ where: { id: carer.id } })).divisionId! } },
    });
    // Visible to the mother only (her division), then shared with the caregiver.
    await prisma.user.update({ where: { id: carer.id }, data: { divisionId: otherDivision!.id, districtId: null, upazilaId: null } });
    const notice = await liveNotice((await prisma.user.findUniqueOrThrow({ where: { id: mother.id } })).divisionId!);

    await http().get(`/api/notices/shared/${notice.id}`).set(auth(carer.token)).expect(404);
    await http().post(`/api/notices/${notice.id}/share-family`).set(auth(carer.token)).expect(404); // not visible to him
    await http().post(`/api/notices/${notice.id}/share-family`).set(auth(mother.token)).expect(201);
    const shared = await http().get(`/api/notices/shared/${notice.id}`).set(auth(carer.token)).expect(200);
    expect(shared.body.title).toBe('Dengue alert');
    await http().get(`/api/notices/shared/${notice.id}`).set(auth(stranger.token)).expect(404);
  });

  it('sharing needs a family', async () => {
    const alone = await account('Solo');
    const notice = await liveNotice();
    await http().post(`/api/notices/${notice.id}/share-family`).set(auth(alone.token)).expect(404);
  });

  it('change history: caregiver changes only, on both sides; nobody else may read it', async () => {
    const carer = await account('Rafi');
    const mother = await account('Amma');
    const sister = await account('Bon');
    await family(carer, mother, sister);

    // The mother's own change: not listed.
    await http().post('/api/medicine-schedule/routines').set(auth(mother.token)).send({
      medicineName: 'Napa', timesPerDay: 1, scheduleTimes: ['08:00'], durationDays: 5,
    }).expect(201);
    // The caregiver's changes: listed.
    await http().post(`/api/medicine-schedule/routines?forUserId=${mother.id}`).set(auth(carer.token)).send({
      medicineName: 'Seclo', timesPerDay: 1, scheduleTimes: ['09:00'], durationDays: 5,
    }).expect(201);
    await http().put(`/api/family/members/${mother.id}/easy-mode`).set(auth(carer.token)).send({ on: true }).expect(200);

    const mine = await http().get('/api/family/changes').set(auth(mother.token)).expect(200);
    expect(mine.body.items.map((i: any) => i.action)).toEqual(['user.easy_mode', 'routine.create']);
    expect(mine.body.items[0].actor).toEqual({ id: carer.id, name: 'Rafi', deleted: false });
    expect(JSON.stringify(mine.body)).not.toContain('Seclo');

    const theirs = await http().get(`/api/family/members/${mother.id}/changes`).set(auth(carer.token)).expect(200);
    expect(theirs.body.items).toHaveLength(2);

    await http().get(`/api/family/members/${mother.id}/changes`).set(auth(sister.token)).expect(404);
    expect((await http().get('/api/family/changes').set(auth(sister.token)).expect(200)).body.items).toEqual([]);

    // Hide from family: the caregiver loses the page, the member keeps hers.
    await prisma.user.update({ where: { id: mother.id }, data: { profileVisibleToFamily: false } });
    await http().get(`/api/family/members/${mother.id}/changes`).set(auth(carer.token)).expect(404);
    await http().get('/api/family/changes').set(auth(mother.token)).expect(200);
  });

  it('change history pages 10 at a time', async () => {
    const carer = await account('Rafi');
    const mother = await account('Amma');
    await family(carer, mother);
    for (let i = 0; i < 12; i++) {
      await http().put(`/api/family/members/${mother.id}/easy-mode`).set(auth(carer.token)).send({ on: i % 2 === 0 }).expect(200);
    }
    const p1 = await http().get('/api/family/changes').set(auth(mother.token)).expect(200);
    expect(p1.body.items).toHaveLength(10);
    const p2 = await http().get(`/api/family/changes?cursor=${p1.body.nextCursor}`).set(auth(mother.token)).expect(200);
    expect(p2.body.items).toHaveLength(2);
    expect(p2.body.nextCursor).toBeNull();
  });
});
