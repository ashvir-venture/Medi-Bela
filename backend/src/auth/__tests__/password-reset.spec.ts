import { BadRequestException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { AuthService } from '../auth.service';
import { JwtAccessStrategy } from '../strategies/jwt-access.strategy';

const PHONE = '+8801712345678';

function setup(opts: { user?: any | null } = {}) {
  const user = opts.user === undefined ? { id: 'u1', phone: PHONE, accountStatus: 'ACTIVE', passwordHash: 'old-hash' } : opts.user;
  let code: any = null;
  const prisma: any = {
    user: {
      findUnique: jest.fn(async () => user),
      update: jest.fn(async ({ data }: any) => Object.assign(user, data)),
    },
    passwordResetCode: {
      upsert: jest.fn(async ({ create, update }: any) => (code = { id: 'c1', ...(code ? update : create) })),
      findUnique: jest.fn(async () => (code ? { ...code } : null)),
      update: jest.fn(async ({ data }: any) => { if (data.attempts?.increment) code.attempts += 1; return code; }),
      deleteMany: jest.fn(async () => { const n = code ? 1 : 0; code = null; return { count: n }; }),
    },
  };
  prisma.$transaction = async (fn: any) => fn(prisma);
  const sms = { send: jest.fn(async (_to: string, _text: string) => true) };
  const config = { getOrThrow: () => 'test-secret', get: () => undefined };
  const service = new AuthService(prisma, {} as any, config as any, sms as any);
  const sentCode = () => /(\d{6})/.exec((sms.send.mock.calls.at(-1) as any)[1])![1];
  const flush = () => new Promise((r) => setImmediate(r));
  return { service, prisma, sms, user, sentCode, flush, getCode: () => code, setCode: (c: any) => (code = c) };
}
const reset = (s: ReturnType<typeof setup>, code: string, ip = '1.1.1.1') =>
  s.service.resetPassword({ phone: PHONE, code, newPassword: 'NewPass123' }, ip);

describe('forgot password', () => {
  it('answers identically for an existing and an unknown number (no account enumeration)', async () => {
    const known = setup();
    const unknown = setup({ user: null });
    const a = await known.service.forgotPassword({ phone: PHONE });
    const b = await unknown.service.forgotPassword({ phone: PHONE });
    await known.flush(); await unknown.flush();
    expect(a).toEqual(b);
    expect(known.sms.send).toHaveBeenCalledTimes(1);
    expect(unknown.sms.send).not.toHaveBeenCalled();
  });

  it('texts a 6-digit code ONLY to the account phone, stores only a hash, and does not return the code', async () => {
    const s = setup();
    const res = await s.service.forgotPassword({ phone: PHONE });
    await s.flush();
    expect(JSON.stringify(res)).not.toMatch(/\d{6}/);
    expect(s.sms.send.mock.calls[0][0]).toBe(PHONE);
    const code = s.sentCode();
    expect(code).toMatch(/^\d{6}$/);
    expect(JSON.stringify(s.getCode())).not.toContain(code);
  });

  it('suspended accounts get no code; a new request replaces the previous code', async () => {
    const s = setup({ user: { id: 'u1', phone: PHONE, accountStatus: 'SUSPENDED' } });
    await s.service.forgotPassword({ phone: PHONE });
    await s.flush();
    expect(s.sms.send).not.toHaveBeenCalled();
    const t = setup();
    await t.service.forgotPassword({ phone: PHONE }); await t.flush();
    const first = t.getCode().codeHash;
    await t.service.forgotPassword({ phone: PHONE }); await t.flush();
    expect(t.getCode().codeHash).not.toBe(first);
  });

  it('limits requests: 3 texts per phone per hour (silently), 10 per IP per hour (429)', async () => {
    const s = setup();
    for (let i = 0; i < 5; i++) { await s.service.forgotPassword({ phone: PHONE }, `ip-${i}`); await s.flush(); }
    expect(s.sms.send).toHaveBeenCalledTimes(3);
    const t = setup();
    for (let i = 0; i < 10; i++) await t.service.forgotPassword({ phone: `+88017${i}` }, 'same-ip');
    await expect(t.service.forgotPassword({ phone: '+8801999' }, 'same-ip')).rejects.toMatchObject({ status: 429 });
  });
});

describe('reset password', () => {
  async function requested() {
    const s = setup();
    await s.service.forgotPassword({ phone: PHONE });
    await s.flush();
    return s;
  }

  it('correct code: password changes (argon2), sessions revoked via passwordChangedAt, code consumed', async () => {
    const s = await requested();
    await reset(s, s.sentCode());
    const update = s.prisma.user.update.mock.calls[0][0];
    expect(await argon2.verify(update.data.passwordHash, 'NewPass123')).toBe(true);
    expect(update.data.passwordChangedAt).toBeInstanceOf(Date);
    expect(s.getCode()).toBeNull();
  });

  it('a code works once only', async () => {
    const s = await requested();
    const code = s.sentCode();
    await reset(s, code);
    await expect(reset(s, code)).rejects.toThrow(BadRequestException);
  });

  it('wrong code: generic error; the code dies after 5 wrong guesses even if the right one follows', async () => {
    const s = await requested();
    const right = s.sentCode();
    const wrong = right === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) await expect(reset(s, wrong, `ip${i}`)).rejects.toThrow('Invalid or expired code');
    await expect(reset(s, right, 'ip-new')).rejects.toThrow('Invalid or expired code');
    expect(s.prisma.user.update).not.toHaveBeenCalled();
  });

  it('expired code is rejected; unknown phone gives the SAME error (no enumeration)', async () => {
    const s = await requested();
    s.setCode({ ...s.getCode(), expiresAt: new Date(Date.now() - 1000) });
    await expect(reset(s, s.sentCode())).rejects.toThrow('Invalid or expired code');
    const none = setup({ user: null });
    await expect(reset(none, '123456')).rejects.toThrow('Invalid or expired code');
  });

  it('brute force from one client is throttled (429) after repeated failures', async () => {
    const s = await requested();
    for (let i = 0; i < 8; i++) await reset(s, '999999').catch(() => undefined);
    await expect(reset(s, '999999')).rejects.toMatchObject({ status: 429 });
  });
});

describe('sessions are revoked by a reset', () => {
  const strategy = (passwordChangedAt: Date | null) =>
    new JwtAccessStrategy({ getOrThrow: () => 'secret' } as any, {
      user: { findUnique: async () => ({ id: 'u1', phone: PHONE, role: 'USER', accountStatus: 'ACTIVE', passwordChangedAt }) },
    } as any);
  const iat = (d: Date) => Math.floor(d.getTime() / 1000);

  it('rejects tokens issued before the reset, accepts ones issued after (and when never reset)', async () => {
    const resetAt = new Date('2026-06-01T12:00:00Z');
    const s = strategy(resetAt);
    await expect(s.validate({ sub: 'u1', phone: PHONE, role: 'USER' as any, iat: iat(resetAt) - 60 })).rejects.toThrow(UnauthorizedException);
    await expect(s.validate({ sub: 'u1', phone: PHONE, role: 'USER' as any, iat: iat(resetAt) + 1 })).resolves.toMatchObject({ id: 'u1' });
    await expect(strategy(null).validate({ sub: 'u1', phone: PHONE, role: 'USER' as any, iat: 1 })).resolves.toBeDefined();
  });
});

describe('change password (profile)', () => {
  it('wrong current password is throttled so a stolen session cannot brute-force it', async () => {
    const hash = await argon2.hash('Correct123');
    const s = setup({ user: { id: 'u1', passwordHash: hash } });
    for (let i = 0; i < 8; i++) await expect(s.service.changePassword('u1', { currentPassword: 'bad', newPassword: 'NewPass123' })).rejects.toThrow(ForbiddenException);
    await expect(s.service.changePassword('u1', { currentPassword: 'Correct123', newPassword: 'NewPass123' })).rejects.toMatchObject({ status: 429 });
  });
});
