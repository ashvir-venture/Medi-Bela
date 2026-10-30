import { Injectable, NotFoundException } from '@nestjs/common';
import { AccountStatus, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { appDayBounds, appUtcOffsetMinutes } from '../common/utils/time.util';
import { ADMIN_PAGE_SIZE, CursorPage } from '../common/utils/cursor-pagination';
import { TtlCache } from '../common/utils/ttl-cache';
import { DOCTOR_INCOMPLETE_WHERE, MEDICINE_INCOMPLETE_WHERE } from '../catalog/lib/catalog-completeness';
import { RankedRow, rankDoctors, rankMedicines } from '../catalog/lib/patient-counts';

/** Numbers may be up to this old; the response says when they were computed. */
export const ANALYTICS_CACHE_MS = 5 * 60_000;
export const TOP_LIMIT = 10;
export const AGE_BANDS = ['0-17', '18-39', '40-59', '60+'] as const;

/** The people the breakdowns describe: patients, not staff, not deleted. */
const COUNTED_USERS: Prisma.UserWhereInput = {
  role: Role.USER,
  accountStatus: { not: AccountStatus.DELETED },
};

function statusCount(rows: { accountStatus: AccountStatus; _count: { _all: number } }[], status: AccountStatus) {
  return rows.find((r) => r.accountStatus === status)?._count._all ?? 0;
}

interface Bucket {
  id: number;
  name: string;
  count: number;
}

/**
 * Admin analytics: users by area / gender / age, families, the catalog's
 * completeness and the doctors and medicines with the most patients.
 * Live queries on indexed columns behind a 5-minute in-memory cache (the Q2
 * decision: no rollup table unless Round 9's query audit shows it's needed).
 * Counts and catalog names only; no patient or health detail.
 */
@Injectable()
export class AdminAnalyticsService {
  private readonly cache = new TtlCache<unknown>(ANALYTICS_CACHE_MS);

  constructor(private readonly prisma: PrismaService) {}

  getOverview(now: Date = new Date()) {
    return this.cached('overview', () => this.loadOverview(now));
  }

  getDivision(divisionId: number) {
    return this.cached(`division:${divisionId}`, () => this.loadDivision(divisionId));
  }

  /** All doctors with patients, ranked, 20 per page. */
  listTopDoctors(cursor?: string) {
    const offset = cursor ? Number(cursor) : 0;
    return this.cached(`doctors:${offset}`, async () =>
      this.rankedPage(await rankDoctors(this.prisma, ADMIN_PAGE_SIZE + 1, offset), offset, (ids) =>
        this.doctorsById(ids),
      ),
    );
  }

  /** All catalog medicines with patients, ranked, 20 per page. */
  listTopMedicines(cursor?: string) {
    const offset = cursor ? Number(cursor) : 0;
    return this.cached(`medicines:${offset}`, async () =>
      this.rankedPage(await rankMedicines(this.prisma, ADMIN_PAGE_SIZE + 1, offset), offset, (ids) =>
        this.medicinesById(ids),
      ),
    );
  }

  private cached<T>(key: string, load: () => Promise<T>): Promise<T> {
    return this.cache.get(key, load) as Promise<T>;
  }

  private async loadOverview(now: Date) {
    const [
      totalUsers,
      byStatusRows,
      byDivisionRows,
      byGenderRows,
      ageRows,
      divisions,
      genders,
      families,
      familyMembers,
      doctors,
      medicines,
      incompleteDoctors,
      incompleteMedicines,
      topDoctorRows,
      topMedicineRows,
    ] = await Promise.all([
      this.prisma.user.count({ where: COUNTED_USERS }),
      this.prisma.user.groupBy({
        by: ['accountStatus'],
        where: COUNTED_USERS,
        _count: { _all: true },
      }),
      this.prisma.user.groupBy({
        by: ['divisionId'],
        where: COUNTED_USERS,
        _count: { _all: true },
      }),
      this.prisma.user.groupBy({
        by: ['genderId'],
        where: COUNTED_USERS,
        _count: { _all: true },
      }),
      this.ageBands(now),
      this.prisma.division.findMany({ orderBy: { name: 'asc' } }),
      this.prisma.gender.findMany({ orderBy: { id: 'asc' } }),
      this.prisma.family.count(),
      this.prisma.familyMember.count(),
      this.prisma.doctor.count(),
      this.prisma.medicine.count(),
      this.prisma.doctor.count({ where: DOCTOR_INCOMPLETE_WHERE }),
      this.prisma.medicine.count({ where: MEDICINE_INCOMPLETE_WHERE }),
      rankDoctors(this.prisma, TOP_LIMIT, 0),
      rankMedicines(this.prisma, TOP_LIMIT, 0),
    ]);

    const byDivision = buckets(
      divisions,
      byDivisionRows.map((r) => [r.divisionId, r._count._all]),
    );
    const byGender = buckets(
      genders,
      byGenderRows.map((r) => [r.genderId, r._count._all]),
    );

    return {
      generatedAt: now.toISOString(),
      cacheSeconds: ANALYTICS_CACHE_MS / 1000,
      users: {
        total: totalUsers,
        byStatus: {
          active: statusCount(byStatusRows, AccountStatus.ACTIVE),
          deactivated: statusCount(byStatusRows, AccountStatus.DEACTIVATED),
          suspended: statusCount(byStatusRows, AccountStatus.SUSPENDED),
        },
        byDivision: byDivision.rows,
        divisionNotSet: byDivision.notSet,
        byGender: byGender.rows,
        genderNotSet: byGender.notSet,
        byAge: AGE_BANDS.map((band) => ({
          band,
          count: ageRows.get(band) ?? 0,
        })),
        ageNotSet: ageRows.get('notSet') ?? 0,
      },
      families: { total: families, members: familyMembers },
      catalog: { doctors, medicines, incompleteDoctors, incompleteMedicines },
      topDoctors: withDetails(topDoctorRows, await this.doctorsById(topDoctorRows.map((r) => r.id))),
      topMedicines: withDetails(topMedicineRows, await this.medicinesById(topMedicineRows.map((r) => r.id))),
    };
  }

  private async loadDivision(divisionId: number) {
    const division = await this.prisma.division.findUnique({
      where: { id: divisionId },
    });
    if (!division) throw new NotFoundException('Division not found');
    const where = { ...COUNTED_USERS, divisionId };
    const [districts, rows] = await Promise.all([
      this.prisma.district.findMany({
        where: { divisionId },
        orderBy: { name: 'asc' },
        select: { id: true, name: true },
      }),
      this.prisma.user.groupBy({
        by: ['districtId'],
        where,
        _count: { _all: true },
      }),
    ]);
    const result = buckets(
      districts,
      rows.map((r) => [r.districtId, r._count._all]),
    );
    return {
      generatedAt: new Date().toISOString(),
      division: { id: division.id, name: division.name },
      districts: result.rows,
      notSet: result.notSet,
    };
  }

  /**
   * Age on today's date in the app's timezone, per band; 'notSet' = no date
   * of birth. A deleted account keeps only birthYear (age = this year - it).
   */
  private async ageBands(now: Date): Promise<Map<string, number>> {
    const today = new Date(appDayBounds(now).start.getTime() + appUtcOffsetMinutes() * 60_000)
      .toISOString()
      .slice(0, 10);
    const rows = await this.prisma.$queryRaw<{ band: string; n: number }[]>(Prisma.sql`
      SELECT band, COUNT(*)::int AS n FROM (
        SELECT CASE
          WHEN years IS NULL THEN 'notSet'
          WHEN years < 18 THEN '0-17'
          WHEN years < 40 THEN '18-39'
          WHEN years < 60 THEN '40-59'
          ELSE '60+'
        END AS band
        FROM (
          SELECT CASE
            WHEN "dateOfBirth" IS NOT NULL THEN date_part('year', age(${today}::date, "dateOfBirth"))
            WHEN "birthYear" IS NOT NULL THEN date_part('year', ${today}::date) - "birthYear"
          END AS years
          FROM users
          WHERE role = 'USER' AND "accountStatus" <> 'DELETED'
        ) aged
      ) banded
      GROUP BY band`);
    return new Map(rows.map((r) => [r.band, r.n]));
  }

  private async rankedPage<D extends { id: string }>(
    rows: RankedRow[],
    offset: number,
    details: (ids: string[]) => Promise<D[]>,
  ): Promise<CursorPage<D & { rank: number; patients: number }>> {
    const pageRows = rows.slice(0, ADMIN_PAGE_SIZE);
    const items = withDetails(pageRows, await details(pageRows.map((r) => r.id))).map((item, i) => ({
      ...item,
      rank: offset + i + 1,
    }));
    return {
      items,
      nextCursor: rows.length > ADMIN_PAGE_SIZE ? String(offset + ADMIN_PAGE_SIZE) : null,
    };
  }

  private doctorsById(ids: string[]) {
    if (ids.length === 0) return Promise.resolve([]);
    return this.prisma.doctor.findMany({
      where: { id: { in: ids } },
      select: {
        id: true,
        name: true,
        specialty: { select: { id: true, name: true } },
      },
    });
  }

  private medicinesById(ids: string[]) {
    if (ids.length === 0) return Promise.resolve([]);
    return this.prisma.medicine.findMany({
      where: { id: { in: ids } },
      select: {
        id: true,
        brandName: true,
        manufacturer: true,
        form: { select: { id: true, name: true } },
      },
    });
  }
}

/** Every lookup row with its count (zeros included); null keys become notSet. */
export function buckets(
  lookup: { id: number; name: string }[],
  counts: [number | null, number][],
): { rows: Bucket[]; notSet: number } {
  const byId = new Map<number, number>();
  let notSet = 0;
  for (const [id, n] of counts) {
    if (id === null) notSet += n;
    else byId.set(id, (byId.get(id) ?? 0) + n);
  }
  return {
    rows: lookup.map((l) => ({
      id: l.id,
      name: l.name,
      count: byId.get(l.id) ?? 0,
    })),
    notSet,
  };
}

/** Joins ranked ids to their records, keeping the ranking order. */
function withDetails<D extends { id: string }>(rows: RankedRow[], details: D[]) {
  const byId = new Map(details.map((d) => [d.id, d]));
  return rows.flatMap((r) => {
    const d = byId.get(r.id);
    return d ? [{ ...d, patients: r.patients }] : [];
  });
}
