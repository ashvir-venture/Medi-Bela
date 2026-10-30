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

/**
 * The registration fields required since Round 6, valid against the lookup
 * tables (pending SQL 003 seeds them; minimal rows are created if absent).
 */
let detailsPromise: Promise<Record<string, unknown>> | null = null;
export function signupDetails(prisma: any): Promise<Record<string, unknown>> {
  if (!detailsPromise) {
    detailsPromise = (async () => {
      const gender = (await prisma.gender.findFirst()) ?? (await prisma.gender.create({ data: { name: 'Test gender' } }));
      let upazila = await prisma.upazila.findFirst({ include: { district: true } });
      if (!upazila) {
        const division = await prisma.division.create({ data: { name: 'Test division' } });
        const district = await prisma.district.create({ data: { name: 'Test district', divisionId: division.id } });
        upazila = await prisma.upazila.create({
          data: { name: 'Test upazila', districtId: district.id },
          include: { district: true },
        });
      }
      return {
        dateOfBirth: '1960-05-20',
        genderId: gender.id,
        divisionId: upazila.district.divisionId,
        districtId: upazila.districtId,
        upazilaId: upazila.id,
        // Round 11: sign-up requires the Privacy & terms box.
        acceptTerms: true,
      };
    })();
  }
  return detailsPromise;
}

export const FAKE_KEY_CONFIG = {
  getOrThrow: () => Buffer.alloc(32, 7).toString('base64'),
  get: () => undefined,
} as any;
