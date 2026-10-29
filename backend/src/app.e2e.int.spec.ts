import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from './app.module';
import { PrismaService } from './prisma/prisma.service';
import { makeTestPrisma, resetDb, signupDetails } from './test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

d('HTTP end-to-end (real AppModule + Postgres)', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const reg = async (phone: string, name: string) => {
    const res = await http().post('/api/auth/register').send({ phone, name, password: 'pass1234', ...(await signupDetails(prisma)) }).expect(201);
    return { token: res.body.tokens.accessToken as string, id: res.body.user.id as string, user: res.body.user };
  };
  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService).useValue(prisma).compile();
    app = mod.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, transformOptions: { enableImplicitConversion: true } }));
    app.setGlobalPrefix('api');
    await app.init();
  });
  afterAll(async () => { await app.close(); await prisma.$disconnect(); });
  beforeEach(async () => { await resetDb(prisma); });

  it('auth works end to end with a single JWT (register, login, protected call, bad token)', async () => {
    const r = await http().post('/api/auth/register').send({ phone: '01711000001', name: 'Local User', password: 'pass1234', ...(await signupDetails(prisma)) }).expect(201);
    expect(r.body.user.phone).toBe('+8801711000001');                       // normalised on the way in
    expect(Object.keys(r.body.tokens)).toEqual(['accessToken']);
    expect(JSON.stringify(r.body)).not.toMatch(/passwordHash|refresh/i);
    const login = await http().post('/api/auth/login').send({ phone: '+88 01711-000001', password: 'pass1234' }).expect(200);
    await http().get('/api/family').set(auth(login.body.tokens.accessToken)).expect(404);   // authenticated, just no family yet
    await http().get('/api/family').set(auth('not-a-token')).expect(401);
    await http().post('/api/auth/logout').set(auth(login.body.tokens.accessToken)).expect(204);
  });

  it('every Phase 4A route rejects unauthenticated calls', async () => {
    for (const [m, path] of [
      ['get', '/family'], ['post', '/family'], ['get', '/family/members'], ['get', '/family/members/status'],
      ['get', '/family/members/00000000-0000-4000-8000-000000000000/status'], ['post', '/family/invitations'],
      ['get', '/family/invitations'], ['get', '/notifications'], ['post', '/notifications/read-all'],
      ['post', '/notifications/devices'], ['post', '/notifications/devices/unregister'],
    ] as const) {
      await (http() as any)[m](`/api${path}`).expect(401);
    }
  });

  it('full family flow over HTTP, with isolation between two families', async () => {
    const owner = await reg('+8801711000010', 'Owner');
    const mem = await reg('+8801711000011', 'Member');
    const out = await reg('+8801711000012', 'Outsider');

    await http().post('/api/family').set(auth(owner.token)).send({ name: 'Home' }).expect(201);
    await http().post('/api/family').set(auth(owner.token)).send({}).expect(409);
    await http().post('/api/family').set(auth(out.token)).send({}).expect(201);

    const inv = await http().post('/api/family/invitations').set(auth(owner.token)).send({ phone: '01711000011' }).expect(201);
    expect(Object.keys(inv.body).sort()).toEqual(['createdAt', 'expiresAt', 'familyId', 'id', 'invitedPhone', 'status']);
    await http().post('/api/family/invitations').set(auth(mem.token)).send({ phone: '+8801711000099' }).expect(404); // not in a family

    const incoming = await http().get('/api/family/invitations').set(auth(mem.token)).expect(200);
    expect(incoming.body).toHaveLength(1);
    expect(incoming.body[0].invitedBy).toEqual({ name: 'Owner' });
    await http().post(`/api/family/invitations/${inv.body.id}/accept`).set(auth(out.token)).expect(404);  // not theirs
    await http().post(`/api/family/invitations/${inv.body.id}/accept`).set(auth(mem.token)).expect(201);

    const members = await http().get('/api/family/members').set(auth(mem.token)).expect(200);
    expect(members.body.map((m: any) => m.user.name).sort()).toEqual(['Member', 'Owner']);
    const outMembers = await http().get('/api/family/members').set(auth(out.token)).expect(200);
    expect(outMembers.body.map((m: any) => m.user.name)).toEqual(['Outsider']);   // never sees Home

    const summary = await http().get('/api/family/members/status').set(auth(owner.token)).expect(200);
    expect(summary.body.members.map((m: any) => m.name)).toEqual(['Member']);
    await http().get(`/api/family/members/${mem.id}/status`).set(auth(owner.token)).expect(200);
    await http().get(`/api/family/members/${mem.id}/status`).set(auth(out.token)).expect(404);   // other family
    await http().get('/api/family/members/not-a-uuid/status').set(auth(owner.token)).expect(400);
  });

  it('device token + inbox endpoints validate input and never echo tokens back', async () => {
    const u = await reg('+8801711000020', 'User');
    const token = 'x'.repeat(60);
    await http().post('/api/notifications/devices').set(auth(u.token)).send({ token: 'short', platform: 'ANDROID' }).expect(400);
    await http().post('/api/notifications/devices').set(auth(u.token)).send({ token, platform: 'WINDOWS' }).expect(400);
    await http().post('/api/notifications/devices').set(auth(u.token)).send({ token, platform: 'ANDROID', extra: 1 }).expect(400);
    const ok = await http().post('/api/notifications/devices').set(auth(u.token)).send({ token, platform: 'ANDROID' }).expect(204);
    expect(ok.text).toBe('');
    const list = await http().get('/api/notifications?limit=500').set(auth(u.token)).expect(400);
    expect(JSON.stringify(list.body)).not.toContain(token);
    await http().get('/api/notifications?limit=10').set(auth(u.token)).expect(200);
    await http().post('/api/notifications/devices/unregister').set(auth(u.token)).send({ token }).expect(204);
    expect(await prisma.deviceToken.count()).toBe(0);
    await http().post('/api/notifications/00000000-0000-4000-8000-000000000000/read').set(auth(u.token)).expect(404);
  });
});
