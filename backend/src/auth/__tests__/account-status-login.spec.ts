import { BadRequestException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { AuthService, SUSPENDED_MESSAGE } from '../auth.service';

const PHONE = '+8801712345678';

/** One user whose status the test picks; the transaction runs on the same mock. */
async function setup(accountStatus: string) {
  const user: any = { id: 'u1', phone: PHONE, role: 'USER', accountStatus, passwordHash: await argon2.hash('pass1234') };
  let code: any = null;
  const prisma: any = {
    user: {
      findUnique: jest.fn(async ({ where }: any) => (where.phone === PHONE ? user : null)),
      findUniqueOrThrow: jest.fn(async () => ({ ...user })),
      update: jest.fn(async ({ data }: any) => Object.assign(user, data)),
      updateMany: jest.fn(async ({ where, data }: any) => {
        if (user.accountStatus !== where.accountStatus) return { count: 0 };
        Object.assign(user, data);
        return { count: 1 };
      }),
    },
    medicineRoutine: { findMany: jest.fn(async () => []) },
    passwordResetCode: {
      upsert: jest.fn(async ({ create }: any) => (code = { id: 'c1', ...create })),
      findUnique: jest.fn(async () => (code ? { ...code } : null)),
      update: jest.fn(async () => code),
      deleteMany: jest.fn(async () => { const n = code ? 1 : 0; code = null; return { count: n }; }),
    },
  };
  prisma.$transaction = async (fn: any) => fn(prisma);
  const sms = { send: jest.fn(async (_to: string, _text: string) => true) };
  const config = { getOrThrow: () => 'test-secret', get: () => undefined };
  const jwt = { signAsync: jest.fn(async () => 'token') };
  const audit = { record: jest.fn(async () => undefined) };
  const service = new AuthService(prisma, jwt as any, config as any, sms as any, audit as any);
  const flush = () => new Promise((r) => setImmediate(r));
  const sentCode = () => /(\d{6})/.exec((sms.send.mock.calls.at(-1) as any)[1])![1];
  return { service, prisma, user, sms, audit, flush, sentCode };
}

describe('login by account status', () => {
  it('DEACTIVATED + right password: reactivated (ACTIVE, audited, routines resumed) and the response says so', async () => {
    const s = await setup('DEACTIVATED');
    const res = await s.service.login({ phone: PHONE, password: 'pass1234' });
    expect(res.reactivated).toBe(true);
    expect(s.user.accountStatus).toBe('ACTIVE');
    expect(s.user.deactivatedAt).toBeNull();
    expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'user.reactivate' }), s.prisma);
    expect(s.prisma.medicineRoutine.findMany).toHaveBeenCalled();
    expect(res.tokens.accessToken).toBe('token');
  });

  it('ACTIVE: no reactivated flag', async () => {
    const s = await setup('ACTIVE');
    const res = await s.service.login({ phone: PHONE, password: 'pass1234' });
    expect(res).not.toHaveProperty('reactivated');
    expect(s.audit.record).not.toHaveBeenCalled();
  });

  it('DEACTIVATED + wrong password: the usual 401, still deactivated', async () => {
    const s = await setup('DEACTIVATED');
    await expect(s.service.login({ phone: PHONE, password: 'nope' })).rejects.toThrow(UnauthorizedException);
    expect(s.user.accountStatus).toBe('DEACTIVATED');
  });

  it('SUSPENDED: the suspension message only after the right password, and login never lifts the ban', async () => {
    const s = await setup('SUSPENDED');
    await expect(s.service.login({ phone: PHONE, password: 'nope' })).rejects.toThrow(UnauthorizedException);
    const err = await s.service.login({ phone: PHONE, password: 'pass1234' }).catch((e) => e);
    expect(err).toBeInstanceOf(ForbiddenException);
    expect(err.message).toBe(SUSPENDED_MESSAGE);
    expect(s.user.accountStatus).toBe('SUSPENDED');
  });
});

describe('SMS reset by account status', () => {
  it('DEACTIVATED: a code is sent and a successful reset reactivates', async () => {
    const s = await setup('DEACTIVATED');
    await s.service.forgotPassword({ phone: PHONE });
    await s.flush();
    expect(s.sms.send).toHaveBeenCalledTimes(1);
    await s.service.resetPassword({ phone: PHONE, code: s.sentCode(), newPassword: 'newpass1' });
    expect(s.user.accountStatus).toBe('ACTIVE');
    expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'user.reactivate' }), s.prisma);
  });

  it('SUSPENDED: silent (no code), and a reset attempt fails like an unknown number', async () => {
    const s = await setup('SUSPENDED');
    const res = await s.service.forgotPassword({ phone: PHONE });
    await s.flush();
    expect(res.message).toMatch(/If an account exists/);
    expect(s.sms.send).not.toHaveBeenCalled();
    await expect(s.service.resetPassword({ phone: PHONE, code: '123456', newPassword: 'newpass1' })).rejects.toThrow(
      BadRequestException,
    );
    expect(s.user.accountStatus).toBe('SUSPENDED');
  });
});
