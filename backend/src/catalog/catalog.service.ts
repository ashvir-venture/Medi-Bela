import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import {
  ADMIN_PAGE_SIZE,
  CURSOR_ORDER,
  cursorWhere,
  toCursorPage,
} from '../common/utils/cursor-pagination';
import {
  CatalogListQueryDto,
  CreateDoctorDto,
  CreateMedicineDto,
  CreateTestDto,
  UpdateDoctorDto,
  UpdateMedicineDto,
} from './dto/catalog.dto';

export const SUGGEST_LIMIT = 10;

const DOCTOR_INCLUDE = {
  specialty: true,
  district: { select: { id: true, name: true } },
} as const;

const MEDICINE_INCLUDE = { form: true, category: true } as const;

/** Doctor columns safe for the audit log (no phone numbers). */
function doctorAuditView(d: { name: string; bmdcNumber: string | null; specialtyId: number | null; chamber: string | null; districtId: number | null }) {
  return {
    name: d.name,
    bmdcNumber: d.bmdcNumber,
    specialtyId: d.specialtyId,
    chamber: d.chamber,
    districtId: d.districtId,
  };
}

function medicineAuditView(m: { brandName: string; genericName: string | null; formId: number | null; categoryId: number | null; manufacturer: string | null }) {
  return {
    brandName: m.brandName,
    genericName: m.genericName,
    formId: m.formId,
    categoryId: m.categoryId,
    manufacturer: m.manufacturer,
  };
}

/**
 * Lower-cased LIKE pattern for a prefix search, with LIKE wildcards in the
 * user's text escaped. Matches the `lower(...) text_pattern_ops` indexes
 * from pending SQL 004.
 */
export function prefixPattern(q: string): string {
  return `${q.trim().toLowerCase().replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
}

/** Keeps rows in the order of `ids` (the raw search query's ranking). */
function inOrder<T extends { id: string }>(ids: string[], rows: T[]): T[] {
  const byId = new Map(rows.map((r) => [r.id, r]));
  return ids.map((id) => byId.get(id)).filter((r): r is T => r !== undefined);
}

function isUniqueError(e: unknown): boolean {
  return e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';
}

/**
 * Doctors, medicines and diagnostic tests. Pharmacists create and complete
 * these records; admins only read them. Strength is not stored here: it
 * lives on the prescription line.
 */
@Injectable()
export class CatalogService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  // --- Autosuggest (prefix, case-insensitive) --------------------------

  async searchDoctors(q: string) {
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      SELECT id FROM doctors
      WHERE lower(name) LIKE ${prefixPattern(q)}
      ORDER BY lower(name), id
      LIMIT ${SUGGEST_LIMIT}`);
    const ids = rows.map((r) => r.id);
    if (ids.length === 0) return [];
    return inOrder(
      ids,
      await this.prisma.doctor.findMany({ where: { id: { in: ids } }, include: DOCTOR_INCLUDE }),
    );
  }

  /** Matches the brand name or the generic name. */
  async searchMedicines(q: string) {
    const pattern = prefixPattern(q);
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      SELECT id FROM medicines
      WHERE lower("brandName") LIKE ${pattern} OR lower("genericName") LIKE ${pattern}
      ORDER BY lower("brandName"), id
      LIMIT ${SUGGEST_LIMIT}`);
    const ids = rows.map((r) => r.id);
    if (ids.length === 0) return [];
    return inOrder(
      ids,
      await this.prisma.medicine.findMany({ where: { id: { in: ids } }, include: MEDICINE_INCLUDE }),
    );
  }

  async searchTests(q: string) {
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      SELECT id FROM diagnostic_tests
      WHERE lower(name) LIKE ${prefixPattern(q)}
      ORDER BY lower(name), id
      LIMIT ${SUGGEST_LIMIT}`);
    const ids = rows.map((r) => r.id);
    if (ids.length === 0) return [];
    return inOrder(
      ids,
      await this.prisma.diagnosticTest.findMany({
        where: { id: { in: ids } },
        include: { category: true },
      }),
    );
  }

  // --- Doctors ------------------------------------------------------------

  async listDoctors(query: CatalogListQueryDto) {
    const where: Prisma.DoctorWhereInput = {
      ...(query.q ? { name: { startsWith: query.q, mode: 'insensitive' } } : {}),
      // "Incomplete" = still missing what identifies a doctor reliably.
      ...(query.incomplete ? { OR: [{ bmdcNumber: null }, { specialtyId: null }] } : {}),
    };
    const rows = await this.prisma.doctor.findMany({
      where: { AND: [where, cursorWhere(query.cursor)] },
      orderBy: CURSOR_ORDER,
      take: ADMIN_PAGE_SIZE + 1,
      include: { ...DOCTOR_INCLUDE, _count: { select: { prescriptions: true } } },
    });
    return toCursorPage(rows, ADMIN_PAGE_SIZE);
  }

  async getDoctor(id: string) {
    const doctor = await this.prisma.doctor.findUnique({
      where: { id },
      include: { ...DOCTOR_INCLUDE, _count: { select: { prescriptions: true } } },
    });
    if (!doctor) throw new NotFoundException('Doctor not found');
    return doctor;
  }

  async createDoctor(actorId: string, dto: CreateDoctorDto, tx?: Prisma.TransactionClient) {
    const client = tx ?? this.prisma;
    if (dto.bmdcNumber) {
      // Same BMDC number = same doctor: reuse instead of failing.
      const existing = await client.doctor.findUnique({
        where: { bmdcNumber: dto.bmdcNumber },
        include: DOCTOR_INCLUDE,
      });
      if (existing) return existing;
    }
    const doctor = await client.doctor.create({
      data: {
        name: dto.name,
        bmdcNumber: dto.bmdcNumber || null,
        specialtyId: dto.specialtyId ?? null,
        chamber: dto.chamber || null,
        phone: dto.phone || null,
        districtId: dto.districtId ?? null,
        createdById: actorId,
      },
      include: DOCTOR_INCLUDE,
    });
    await this.audit.record(
      {
        actorId,
        action: 'doctor.create',
        entityType: 'doctor',
        entityId: doctor.id,
        after: doctorAuditView(doctor),
      },
      tx,
    );
    return doctor;
  }

  async updateDoctor(actorId: string, id: string, dto: UpdateDoctorDto) {
    const before = await this.prisma.doctor.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Doctor not found');
    try {
      const doctor = await this.prisma.doctor.update({
        where: { id },
        data: {
          name: dto.name,
          bmdcNumber: dto.bmdcNumber === undefined ? undefined : dto.bmdcNumber || null,
          specialtyId: dto.specialtyId,
          chamber: dto.chamber === undefined ? undefined : dto.chamber || null,
          phone: dto.phone === undefined ? undefined : dto.phone || null,
          districtId: dto.districtId,
        },
        include: DOCTOR_INCLUDE,
      });
      await this.audit.record({
        actorId,
        action: 'doctor.update',
        entityType: 'doctor',
        entityId: id,
        before: doctorAuditView(before),
        after: doctorAuditView(doctor),
      });
      return doctor;
    } catch (e) {
      if (isUniqueError(e)) throw new ConflictException('Another doctor already has this BMDC number');
      throw e;
    }
  }

  // --- Medicines ------------------------------------------------------------

  async listMedicines(query: CatalogListQueryDto) {
    const where: Prisma.MedicineWhereInput = {
      ...(query.q ? { brandName: { startsWith: query.q, mode: 'insensitive' } } : {}),
      ...(query.incomplete
        ? { OR: [{ genericName: null }, { formId: null }, { categoryId: null }] }
        : {}),
    };
    const rows = await this.prisma.medicine.findMany({
      where: { AND: [where, cursorWhere(query.cursor)] },
      orderBy: CURSOR_ORDER,
      take: ADMIN_PAGE_SIZE + 1,
      include: { ...MEDICINE_INCLUDE, _count: { select: { lines: true } } },
    });
    return toCursorPage(rows, ADMIN_PAGE_SIZE);
  }

  async getMedicine(id: string) {
    const medicine = await this.prisma.medicine.findUnique({
      where: { id },
      include: { ...MEDICINE_INCLUDE, _count: { select: { lines: true } } },
    });
    if (!medicine) throw new NotFoundException('Medicine not found');
    return medicine;
  }

  async createMedicine(actorId: string, dto: CreateMedicineDto) {
    try {
      const medicine = await this.prisma.medicine.create({
        data: {
          brandName: dto.brandName,
          genericName: dto.genericName || null,
          formId: dto.formId ?? null,
          categoryId: dto.categoryId ?? null,
          manufacturer: dto.manufacturer || null,
          createdById: actorId,
        },
        include: MEDICINE_INCLUDE,
      });
      await this.audit.record({
        actorId,
        action: 'medicine.create',
        entityType: 'medicine',
        entityId: medicine.id,
        after: medicineAuditView(medicine),
      });
      return medicine;
    } catch (e) {
      if (isUniqueError(e)) throw new ConflictException('This medicine already exists in that form');
      throw e;
    }
  }

  /**
   * A medicine typed on a prescription line that isn't in the catalog yet
   * becomes a stub (brand name only) for a pharmacist to complete later.
   * Matching is case-insensitive on the brand name.
   */
  async findOrCreateMedicineStub(actorId: string, brandName: string, tx: Prisma.TransactionClient) {
    const name = brandName.trim();
    const existing = await tx.medicine.findFirst({
      where: { brandName: { equals: name, mode: 'insensitive' } },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (existing) return existing.id;
    const created = await tx.medicine.create({
      data: { brandName: name, createdById: actorId },
      select: { id: true, brandName: true, genericName: true, formId: true, categoryId: true, manufacturer: true },
    });
    await this.audit.record(
      {
        actorId,
        action: 'medicine.create',
        entityType: 'medicine',
        entityId: created.id,
        after: medicineAuditView(created),
      },
      tx,
    );
    return created.id;
  }

  async updateMedicine(actorId: string, id: string, dto: UpdateMedicineDto) {
    const before = await this.prisma.medicine.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Medicine not found');
    try {
      const medicine = await this.prisma.medicine.update({
        where: { id },
        data: {
          brandName: dto.brandName,
          genericName: dto.genericName === undefined ? undefined : dto.genericName || null,
          formId: dto.formId,
          categoryId: dto.categoryId,
          manufacturer: dto.manufacturer === undefined ? undefined : dto.manufacturer || null,
        },
        include: MEDICINE_INCLUDE,
      });
      await this.audit.record({
        actorId,
        action: 'medicine.update',
        entityType: 'medicine',
        entityId: id,
        before: medicineAuditView(before),
        after: medicineAuditView(medicine),
      });
      return medicine;
    } catch (e) {
      if (isUniqueError(e)) throw new ConflictException('This medicine already exists in that form');
      throw e;
    }
  }

  // --- Diagnostic tests -------------------------------------------------------

  /** Test names are unique (case-insensitive here): an existing one is returned. */
  async createTest(dto: CreateTestDto) {
    const existing = await this.prisma.diagnosticTest.findFirst({
      where: { name: { equals: dto.name, mode: 'insensitive' } },
      include: { category: true },
    });
    if (existing) return existing;
    try {
      return await this.prisma.diagnosticTest.create({
        data: { name: dto.name, categoryId: dto.categoryId ?? null },
        include: { category: true },
      });
    } catch (e) {
      // Two pharmacists adding the same test at once: return the winner.
      if (isUniqueError(e)) {
        const winner = await this.prisma.diagnosticTest.findUnique({
          where: { name: dto.name },
          include: { category: true },
        });
        if (winner) return winner;
      }
      throw e;
    }
  }
}
