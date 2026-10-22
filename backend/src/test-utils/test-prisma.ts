/**
 * Real-database test helper. Integration specs run only when
 * TEST_DATABASE_URL points at a disposable Postgres that already has the
 * schema applied (prisma migrate deploy) plus deliver/phase4a_extra.sql.
 * WARNING: it TRUNCATES data — never point it at a real database.
 */
export function makeTestPrisma(): any | null {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) return null;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient } = require('@prisma/client');
  if (process.env.PRISMA_TEST_PG_ADAPTER === '1') {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { PrismaPg } = require('@prisma/adapter-pg');
    return new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
  }
  return new PrismaClient({ datasources: { db: { url } } });
}

export async function resetDb(prisma: any) {
  await prisma.$executeRawUnsafe(
    'TRUNCATE TABLE notifications, device_tokens, medicine_doses, medicine_routines, family_invitations, family_members, families, users RESTART IDENTITY CASCADE',
  );
}

let phoneSeq = 0;
export function makeUser(prisma: any, name: string, extra: Record<string, unknown> = {}) {
  phoneSeq += 1;
  return prisma.user.create({
    data: { phone: `+88017000${String(phoneSeq).padStart(5, '0')}`, name, passwordHash: 'x', ...extra },
  });
}

export const FAKE_KEY_CONFIG = {
  getOrThrow: () => Buffer.alloc(32, 7).toString('base64'),
  get: () => undefined,
} as any;
