import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as argon2 from 'argon2';
import request from 'supertest';
import { AppModule } from '../../app.module';
import { PrismaService } from '../../prisma/prisma.service';
import { makeTestPrisma, resetDb } from '../../test-utils/test-prisma';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

/**
 * prisma/seed.ts stores SEED_ADMIN_PHONE / SEED_PHARMACIST_PHONE exactly as
 * written (e.g. 01810314801). Login must find that row as typed, while app
 * sign-ups (stored as +880...) still sign in with any spelling.
 */
d('Login with a seeded phone number (real AppModule + Postgres)', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.PUSH_TOKEN_ENC_KEY = Buffer.alloc(32, 9).toString('base64');
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
    app.setGlobalPrefix('api');
    await app.init();
  });
  afterAll(async () => {
    await app.close();
    await prisma.$disconnect();
  });
  beforeEach(() => resetDb(prisma));

  it('signs in a seeded admin whose phone is stored as written (01...)', async () => {
    await prisma.user.create({
      data: {
        phone: '01810314801',
        name: 'Seeded admin',
        role: 'ADMIN',
        passwordHash: await argon2.hash('Seed#pass1'),
      },
    });
    const res = await http().post('/api/auth/login').send({ phone: '01810314801', password: 'Seed#pass1' }).expect(200);
    expect(res.body.user.phone).toBe('01810314801');
    expect(res.body.user.role).toBe('ADMIN');
  });

  it('still signs in an app account stored as +880... when typed as 01...', async () => {
    await prisma.user.create({
      data: {
        phone: '+8801711000009',
        name: 'App user',
        passwordHash: await argon2.hash('pass1234'),
      },
    });
    await http().post('/api/auth/login').send({ phone: '01711000009', password: 'pass1234' }).expect(200);
    await http().post('/api/auth/login').send({ phone: '+8801711000009', password: 'pass1234' }).expect(200);
  });
});
