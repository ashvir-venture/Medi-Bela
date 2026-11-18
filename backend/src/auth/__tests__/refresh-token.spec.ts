import { RefreshClient } from '@prisma/client';
import { hashRefreshToken, RefreshTokenService, REUSE_GRACE_MS } from '../refresh-token.service';
import { readRefreshCookie } from '../refresh-cookie';

type Row = {
  id: string;
  userId: string;
  familyId: string;
  tokenHash: string;
  client: RefreshClient;
  expiresAt: Date;
  usedAt: Date | null;
  revokedAt: Date | null;
  createdAt: Date;
};

/** An in-memory refresh_tokens table with just what the service uses. */
function setup(user: { accountStatus: string; passwordChangedAt: Date | null } = { accountStatus: 'ACTIVE', passwordChangedAt: null }) {
  const rows: Row[] = [];
  let n = 0;
  const match = (r: Row, where: any) =>
    Object.entries(where).every(([k, v]) => {
      if (k === 'NOT') return !match(r, v);
      return (r as any)[k] === v;
    });
  const prisma = {
    refreshToken: {
      create: jest.fn(async ({ data }: any) => {
        const row = { id: `r${++n}`, usedAt: null, revokedAt: null, ...data };
        rows.push(row);
        return row;
      }),
      findUnique: jest.fn(async ({ where }: any) => {
        const row = rows.find((r) => r.tokenHash === where.tokenHash);
        return row ? { ...row, user } : null;
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        const hit = rows.filter((r) => match(r, where));
        hit.forEach((r) => Object.assign(r, data));
        return { count: hit.length };
      }),
      deleteMany: jest.fn(),
    },
  };
  const config = { get: (k: string) => (k === 'REFRESH_TTL_DAYS_PANEL' ? '7' : undefined) };
  const service = new RefreshTokenService(prisma as any, config as any);
  return { service, rows, user };
}

const t0 = new Date('2026-11-18T10:00:00Z');
const later = (ms: number) => new Date(t0.getTime() + ms);

describe('refresh tokens (Round 18)', () => {
  it('stores only a hash; the app gets 60 days, the panel 7', async () => {
    const s = setup();
    const app = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    const panel = await s.service.issue('u1', RefreshClient.PANEL, undefined, t0);
    expect(s.rows[0].tokenHash).toBe(hashRefreshToken(app.token));
    expect(s.rows.some((r) => r.tokenHash === app.token)).toBe(false);
    expect((app.expiresAt.getTime() - t0.getTime()) / 86_400_000).toBe(60);
    expect((panel.expiresAt.getTime() - t0.getTime()) / 86_400_000).toBe(7);
    expect(app.familyId).not.toBe(panel.familyId);
  });

  it('a refresh gives the next token in the same family and marks the old one used', async () => {
    const s = setup();
    const first = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    const next = await s.service.rotate(first.token, later(1000));
    expect(next.familyId).toBe(first.familyId);
    expect(next.token).not.toBe(first.token);
    expect(next.userId).toBe('u1');
    expect(s.rows[0].usedAt).toEqual(later(1000));
    // and the new one works
    await expect(s.service.rotate(next.token, later(2000))).resolves.toMatchObject({ familyId: first.familyId });
  });

  it('a used token again inside the grace window still works (app and reminder isolate racing)', async () => {
    const s = setup();
    const first = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    await s.service.rotate(first.token, later(1000));
    await expect(s.service.rotate(first.token, later(1000 + REUSE_GRACE_MS - 1))).resolves.toBeDefined();
    expect(s.rows.every((r) => r.revokedAt === null)).toBe(true);
  });

  it('a used token again after the grace window signs that whole sign-in out', async () => {
    const s = setup();
    const first = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    const other = await s.service.issue('u1', RefreshClient.APP, undefined, t0); // another phone
    const next = await s.service.rotate(first.token, later(1000));
    await expect(s.service.rotate(first.token, later(1000 + REUSE_GRACE_MS + 1))).rejects.toMatchObject({ errorCode: 'SESSION_EXPIRED' });
    await expect(s.service.rotate(next.token, later(REUSE_GRACE_MS * 3))).rejects.toMatchObject({ status: 401 });
    // the other phone is untouched
    await expect(s.service.rotate(other.token, later(REUSE_GRACE_MS * 3))).resolves.toBeDefined();
  });

  it('refuses unknown, expired and revoked tokens', async () => {
    const s = setup();
    await expect(s.service.rotate('nope', t0)).rejects.toMatchObject({ errorCode: 'SESSION_EXPIRED' });
    await expect(s.service.rotate('', t0)).rejects.toMatchObject({ status: 401 });
    const a = await s.service.issue('u1', RefreshClient.PANEL, undefined, t0);
    await expect(s.service.rotate(a.token, later(8 * 86_400_000))).rejects.toMatchObject({ status: 401 });
    const b = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    await s.service.revokeByToken(b.token, later(1));
    await expect(s.service.rotate(b.token, later(2))).rejects.toMatchObject({ status: 401 });
  });

  it('a token from before a password reset or pause is dead; so is a paused account', async () => {
    const s = setup({ accountStatus: 'ACTIVE', passwordChangedAt: later(5000) });
    const a = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    await expect(s.service.rotate(a.token, later(6000))).rejects.toMatchObject({ status: 401 });
    const p = setup({ accountStatus: 'DEACTIVATED', passwordChangedAt: null });
    const b = await p.service.issue('u1', RefreshClient.APP, undefined, t0);
    await expect(p.service.rotate(b.token, later(1))).rejects.toMatchObject({ status: 401 });
  });

  it('a password change keeps this sign-in and signs out every other one', async () => {
    const s = setup();
    const here = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    const there = await s.service.issue('u1', RefreshClient.APP, undefined, t0);
    await s.service.revokeAllForUser('u1', here.familyId, later(1));
    await expect(s.service.rotate(here.token, later(2))).resolves.toBeDefined();
    await expect(s.service.rotate(there.token, later(2))).rejects.toMatchObject({ status: 401 });
  });

  it('reads the panel cookie from the header', () => {
    expect(readRefreshCookie({ headers: { cookie: 'a=1; mb_refresh=abc%2Bd; b=2' } } as any)).toBe('abc+d');
    expect(readRefreshCookie({ headers: {} } as any)).toBeUndefined();
  });
});
