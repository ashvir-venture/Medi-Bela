import * as argon2 from 'argon2';
import { AuthService } from '../auth.service';

/** Seeded staff phones are stored as written (01...); app sign-ups as +880... */
function setup(users: any[]) {
  const prisma: any = {
    user: {
      findUnique: jest.fn(async ({ where }: any) => users.find((u) => u.phone === where.phone) ?? null),
    },
    passwordResetCode: { upsert: jest.fn(async () => ({})) },
  };
  const sms = { send: jest.fn(async () => true) };
  const config = { getOrThrow: () => 'test-secret', get: () => undefined };
  const jwt = { signAsync: jest.fn(async () => 'token') };
  const service = new AuthService(prisma, jwt as any, config as any, sms as any, { record: jest.fn() } as any);
  return { service, prisma, sms };
}

describe('phone lookup at login and password reset', () => {
  let hash: string;
  beforeAll(async () => {
    hash = await argon2.hash('pass1234');
  });

  it('the number exactly as stored wins over its normalized form', async () => {
    const s = setup([
      {
        id: 'seeded',
        phone: '01810314801',
        passwordHash: hash,
        accountStatus: 'ACTIVE',
      },
      {
        id: 'app',
        phone: '+8801810314801',
        passwordHash: hash,
        accountStatus: 'ACTIVE',
      },
    ]);
    const res = await s.service.login({
      phone: '01810314801',
      password: 'pass1234',
    });
    expect(res.user.id).toBe('seeded');
    expect(s.prisma.user.findUnique).toHaveBeenCalledTimes(1);
  });

  it('falls back to the normalized form for app sign-ups', async () => {
    const s = setup([
      {
        id: 'app',
        phone: '+8801712345678',
        passwordHash: hash,
        accountStatus: 'ACTIVE',
      },
    ]);
    const res = await s.service.login({
      phone: '01712345678',
      password: 'pass1234',
    });
    expect(res.user.id).toBe('app');
  });

  it('another spelling of the same number shares the failed-login throttle', async () => {
    const s = setup([
      {
        id: 'app',
        phone: '+8801712345678',
        passwordHash: hash,
        accountStatus: 'ACTIVE',
      },
    ]);
    const spellings = ['01712345678', '+8801712345678', '8801712345678', '+880 1712-345678'];
    // 8 failures (LoginThrottle's limit), spread over the four spellings.
    for (const phone of [...spellings, ...spellings]) {
      await expect(s.service.login({ phone, password: 'wrong' }, '1.1.1.1')).rejects.toMatchObject({ status: 401 });
    }
    await expect(s.service.login({ phone: '8801712345678', password: 'pass1234' }, '1.1.1.1')).rejects.toMatchObject({
      status: 429,
    });
  });

  it('a reset code for a seeded 01... account is texted in +880... form', async () => {
    const s = setup([
      {
        id: 'seeded',
        phone: '01810314801',
        passwordHash: hash,
        accountStatus: 'ACTIVE',
      },
    ]);
    await s.service.forgotPassword({ phone: '01810314801' });
    await new Promise((r) => setImmediate(r));
    expect((s.sms.send.mock.calls as any[])[0][0]).toBe('+8801810314801');
  });
});
