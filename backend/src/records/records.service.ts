import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AppointmentKind, OwnTestStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { prefixPattern, SUGGEST_LIMIT } from '../catalog/catalog.service';
import {
  CreateAppointmentDto,
  CreateOwnTestDto,
  CreateRecordPrescriptionDto,
  NewDoctorDto,
  TestValueDto,
  UpdateAppointmentDto,
  UpdateOwnTestDto,
  UpdateRecordPrescriptionDto,
} from './dto/records.dto';

/** Pages (photos) one test report or record-only prescription may have. */
export const MAX_PHOTOS = 10;

const dateOnly = (value: string) => new Date(`${value}T00:00:00.000Z`);
const isoDay = (d: Date) => d.toISOString().slice(0, 10);

const CATALOG_DOCTOR_SELECT = {
  id: true,
  name: true,
  chamber: true,
  specialty: { select: { name: true } },
  district: { select: { name: true } },
} as const;
const DOCTOR_INCLUDE = { doctor: { select: CATALOG_DOCTOR_SELECT }, myDoctor: true } satisfies Prisma.AppointmentInclude;
const TEST_INCLUDE = {
  testKind: { select: { code: true } },
  values: { orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }] },
  photos: { orderBy: [{ page: 'asc' }, { createdAt: 'asc' }] },
} satisfies Prisma.OwnTestInclude;

type Photo = { id: string; imageUrl: string; page: number };
type WithDoctor = {
  doctor: { id: string; name: string; chamber: string | null; specialty: { name: string } | null; district: { name: string } | null } | null;
  myDoctor: { id: string; name: string; chamber: string | null; area: string | null } | null;
};

/**
 * Round 16 "Health records 2.0": the patient's private doctors, doctor
 * visits / pregnancy check-ups / chemo sessions, own upcoming tests and test
 * results (values by the owner's test list, photos), and prescriptions kept
 * for the record only (never in the pharmacist queue, no medicines).
 * Photos are private Cloudinary assets; every answer carries 1-hour signed
 * links. The caregiver may do all of it for a member (audited, member told).
 */
@Injectable()
export class RecordsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly caregivers: CaregiverAccessService,
    private readonly cloudinary: CloudinaryService,
  ) {}

  /** Everything on the Health records page (the app caches it). */
  async overview(userId: string) {
    const [myDoctors, appointments, tests, prescriptions] = await Promise.all([
      this.prisma.myDoctor.findMany({ where: { userId }, orderBy: { name: 'asc' } }),
      this.prisma.appointment.findMany({ where: { userId }, include: DOCTOR_INCLUDE, orderBy: [{ date: 'asc' }, { time: 'asc' }] }),
      this.prisma.ownTest.findMany({ where: { userId }, include: TEST_INCLUDE, orderBy: [{ date: 'desc' }, { createdAt: 'desc' }] }),
      this.prisma.recordPrescription.findMany({
        where: { userId },
        include: { ...DOCTOR_INCLUDE, photos: { orderBy: [{ page: 'asc' }, { createdAt: 'asc' }] } },
        orderBy: [{ date: 'desc' }, { createdAt: 'desc' }],
      }),
    ]);
    return {
      myDoctors: myDoctors.map(({ userId: _u, ...d }) => d),
      appointments: appointments.map((a) => this.presentAppointment(a)),
      tests: tests.map((t) => this.presentTest(t)),
      prescriptions: prescriptions.map((p) => this.presentPrescription(p)),
    };
  }

  /** Catalog doctors by name prefix, plus the patient's own. */
  async searchDoctors(userId: string, q: string) {
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      SELECT id FROM doctors WHERE lower(name) LIKE ${prefixPattern(q)}
      ORDER BY lower(name), id LIMIT ${SUGGEST_LIMIT}`);
    const catalog = rows.length
      ? await this.prisma.doctor.findMany({ where: { id: { in: rows.map((r) => r.id) } }, select: CATALOG_DOCTOR_SELECT, orderBy: { name: 'asc' } })
      : [];
    const mine = await this.prisma.myDoctor.findMany({
      where: { userId, name: { startsWith: q, mode: 'insensitive' } },
      orderBy: { name: 'asc' },
      take: SUGGEST_LIMIT,
    });
    return {
      catalog: catalog.map(presentCatalogDoctor),
      mine: mine.map(({ userId: _u, ...d }) => d),
    };
  }

  async addMyDoctor(acting: ActingFor, dto: NewDoctorDto) {
    const row = await this.prisma.myDoctor.create({
      data: { userId: acting.subjectId, name: dto.name, chamber: dto.chamber || null, area: dto.area || null },
    });
    const { userId: _u, ...d } = row;
    return d;
  }

  // --- Appointments ------------------------------------------------------

  async createAppointment(acting: ActingFor, dto: CreateAppointmentDto) {
    await this.checkCondition(dto.conditionCode);
    const doctor = await this.doctorChoice(acting.subjectId, dto);
    const kind = dto.kind ?? AppointmentKind.VISIT;
    const row = await this.prisma.$transaction(async (tx) => {
      const created = await tx.appointment.create({
        data: {
          userId: acting.subjectId,
          kind,
          date: dateOnly(dto.date),
          time: dto.time ?? null,
          ...(await this.resolveDoctor(tx, acting.subjectId, doctor)),
          conditionCode: dto.conditionCode ?? null,
          number: kind === AppointmentKind.ANC ? (dto.number ?? null) : null,
          note: dto.note || null,
          remind: dto.remind ?? true,
          createdById: acting.actorId,
        },
        include: DOCTOR_INCLUDE,
      });
      await this.audited(tx, acting, 'record.appointment_create', 'appointment', created.id, { kind });
      return created;
    });
    await this.tellMember(acting, `appointment:${row.id}`);
    return this.presentAppointment(row);
  }

  async updateAppointment(acting: ActingFor, id: string, dto: UpdateAppointmentDto) {
    const current = await this.prisma.appointment.findUnique({ where: { id } });
    if (!current || current.userId !== acting.subjectId) throw new NotFoundException('Visit not found');
    await this.checkCondition(dto.conditionCode);
    const doctor = await this.doctorChoice(acting.subjectId, dto);
    const row = await this.prisma.$transaction(async (tx) => {
      const saved = await tx.appointment.update({
        where: { id },
        data: {
          ...(dto.date ? { date: dateOnly(dto.date) } : {}),
          ...(dto.time !== undefined ? { time: dto.time } : {}),
          ...(doctor ? await this.resolveDoctor(tx, acting.subjectId, doctor) : {}),
          ...(dto.conditionCode !== undefined ? { conditionCode: dto.conditionCode } : {}),
          ...(dto.number !== undefined && current.kind === AppointmentKind.ANC ? { number: dto.number } : {}),
          ...(dto.note !== undefined ? { note: dto.note || null } : {}),
          ...(dto.remind !== undefined ? { remind: dto.remind } : {}),
          ...(dto.done !== undefined ? { doneAt: dto.done ? (current.doneAt ?? new Date()) : null } : {}),
        },
        include: DOCTOR_INCLUDE,
      });
      await this.audited(tx, acting, 'record.appointment_update', 'appointment', id, { kind: saved.kind });
      return saved;
    });
    await this.tellMember(acting, `appointment:${id}:${Date.now()}`);
    return this.presentAppointment(row);
  }

  async deleteAppointment(acting: ActingFor, id: string) {
    const current = await this.prisma.appointment.findUnique({ where: { id } });
    if (!current || current.userId !== acting.subjectId) throw new NotFoundException('Visit not found');
    await this.prisma.$transaction(async (tx) => {
      await tx.appointment.delete({ where: { id } });
      await this.audited(tx, acting, 'record.appointment_delete', 'appointment', id, { kind: current.kind });
    });
    return { deleted: true };
  }

  // --- Own tests and results ---------------------------------------------

  async createTest(acting: ActingFor, dto: CreateOwnTestDto) {
    if (!dto.testKindCode && !dto.otherName) throw new BadRequestException('Which test?');
    await this.checkCondition(dto.conditionCode);
    const kind = dto.testKindCode
      ? await this.prisma.testKind.findUnique({ where: { code: dto.testKindCode }, include: { fields: true } })
      : null;
    if (dto.testKindCode && !kind) throw new BadRequestException('Unknown test');
    if (dto.healthReminderId) await this.checkReminder(acting.subjectId, dto.healthReminderId);
    const status = dto.status ?? OwnTestStatus.UPCOMING;
    const values = status === OwnTestStatus.DONE ? this.valueRows(kind?.fields ?? [], dto.values ?? []) : [];
    const row = await this.prisma.$transaction(async (tx) => {
      const created = await tx.ownTest.create({
        data: {
          userId: acting.subjectId,
          testKindId: kind?.id ?? null,
          otherName: kind ? null : dto.otherName!,
          status,
          date: dateOnly(dto.date),
          remind: dto.remind ?? true,
          fasting: dto.fasting ?? false,
          findings: dto.findings || null,
          lab: dto.lab || null,
          conditionCode: dto.conditionCode ?? null,
          healthReminderId: dto.healthReminderId ?? null,
          createdById: acting.actorId,
          values: { create: values },
        },
        include: TEST_INCLUDE,
      });
      await this.audited(tx, acting, 'record.test_create', 'own_test', created.id, { status });
      return created;
    });
    await this.tellMember(acting, `test:${row.id}`);
    return this.presentTest(row);
  }

  async updateTest(acting: ActingFor, id: string, dto: UpdateOwnTestDto) {
    const current = await this.prisma.ownTest.findUnique({ where: { id }, include: { testKind: { include: { fields: true } } } });
    if (!current || current.userId !== acting.subjectId) throw new NotFoundException('Test not found');
    await this.checkCondition(dto.conditionCode);
    const status = dto.status ?? current.status;
    const row = await this.prisma.$transaction(async (tx) => {
      if (dto.values) {
        await tx.testResultValue.deleteMany({ where: { ownTestId: id } });
        const values = this.valueRows(current.testKind?.fields ?? [], dto.values);
        if (values.length) await tx.testResultValue.createMany({ data: values.map((v) => ({ ...v, ownTestId: id })) });
      }
      const saved = await tx.ownTest.update({
        where: { id },
        data: {
          status,
          ...(dto.date ? { date: dateOnly(dto.date) } : {}),
          ...(dto.remind !== undefined ? { remind: dto.remind } : {}),
          ...(dto.fasting !== undefined ? { fasting: dto.fasting } : {}),
          ...(dto.findings !== undefined ? { findings: dto.findings || null } : {}),
          ...(dto.lab !== undefined ? { lab: dto.lab || null } : {}),
          ...(dto.conditionCode !== undefined ? { conditionCode: dto.conditionCode } : {}),
        },
        include: TEST_INCLUDE,
      });
      await this.audited(tx, acting, 'record.test_update', 'own_test', id, { status });
      return saved;
    });
    await this.tellMember(acting, `test:${id}:${Date.now()}`);
    return this.presentTest(row);
  }

  async deleteTest(acting: ActingFor, id: string) {
    const current = await this.prisma.ownTest.findUnique({ where: { id }, include: { photos: true } });
    if (!current || current.userId !== acting.subjectId) throw new NotFoundException('Test not found');
    await this.prisma.$transaction(async (tx) => {
      await tx.ownTest.delete({ where: { id } });
      await this.audited(tx, acting, 'record.test_delete', 'own_test', id, { photos: current.photos.length });
    });
    await Promise.all(current.photos.map((p) => this.cloudinary.deleteImageByUrl(p.imageUrl)));
    return { deleted: true };
  }

  /** Field values by the kind's field codes; named values the user added. */
  private valueRows(fields: { id: number; code: string; nameEn: string; unit: string | null }[], values: TestValueDto[]) {
    const byCode = new Map(fields.map((f) => [f.code, f]));
    return values
      .filter((v) => v.value != null || (v.textValue != null && v.textValue !== ''))
      .map((v, i) => {
        if (v.fieldCode) {
          const f = byCode.get(v.fieldCode);
          if (!f) throw new BadRequestException('Unknown value for this test');
          return { fieldId: f.id, name: f.nameEn, value: v.value ?? null, textValue: v.textValue ?? null, unit: f.unit, sortOrder: i };
        }
        if (!v.name) throw new BadRequestException('Name the value');
        return { fieldId: null, name: v.name, value: v.value ?? null, textValue: v.textValue ?? null, unit: v.unit ?? null, sortOrder: i };
      });
  }

  private async checkReminder(userId: string, reminderId: string) {
    const r = await this.prisma.healthReminder.findUnique({ where: { id: reminderId }, select: { userId: true } });
    if (!r || r.userId !== userId) throw new NotFoundException('Test reminder not found');
  }

  // --- Record-only prescriptions -----------------------------------------

  async createPrescription(acting: ActingFor, dto: CreateRecordPrescriptionDto) {
    await this.checkCondition(dto.conditionCode);
    const doctor = await this.doctorChoice(acting.subjectId, dto);
    const row = await this.prisma.$transaction(async (tx) => {
      const created = await tx.recordPrescription.create({
        data: {
          userId: acting.subjectId,
          date: dateOnly(dto.date),
          ...(await this.resolveDoctor(tx, acting.subjectId, doctor)),
          conditionCode: dto.conditionCode ?? null,
          note: dto.note || null,
          createdById: acting.actorId,
        },
        include: { ...DOCTOR_INCLUDE, photos: true },
      });
      await this.audited(tx, acting, 'record.prescription_create', 'record_prescription', created.id, {});
      return created;
    });
    await this.tellMember(acting, `rx:${row.id}`);
    return this.presentPrescription(row);
  }

  async updatePrescription(acting: ActingFor, id: string, dto: UpdateRecordPrescriptionDto) {
    const current = await this.prisma.recordPrescription.findUnique({ where: { id } });
    if (!current || current.userId !== acting.subjectId) throw new NotFoundException('Prescription not found');
    await this.checkCondition(dto.conditionCode);
    const doctor = await this.doctorChoice(acting.subjectId, dto);
    const row = await this.prisma.$transaction(async (tx) => {
      const saved = await tx.recordPrescription.update({
        where: { id },
        data: {
          ...(dto.date ? { date: dateOnly(dto.date) } : {}),
          ...(doctor ? await this.resolveDoctor(tx, acting.subjectId, doctor) : {}),
          ...(dto.conditionCode !== undefined ? { conditionCode: dto.conditionCode } : {}),
          ...(dto.note !== undefined ? { note: dto.note || null } : {}),
        },
        include: { ...DOCTOR_INCLUDE, photos: { orderBy: [{ page: 'asc' }, { createdAt: 'asc' }] } },
      });
      await this.audited(tx, acting, 'record.prescription_update', 'record_prescription', id, {});
      return saved;
    });
    return this.presentPrescription(row);
  }

  async deletePrescription(acting: ActingFor, id: string) {
    const current = await this.prisma.recordPrescription.findUnique({ where: { id }, include: { photos: true } });
    if (!current || current.userId !== acting.subjectId) throw new NotFoundException('Prescription not found');
    await this.prisma.$transaction(async (tx) => {
      await tx.recordPrescription.delete({ where: { id } });
      await this.audited(tx, acting, 'record.prescription_delete', 'record_prescription', id, { photos: current.photos.length });
    });
    await Promise.all(current.photos.map((p) => this.cloudinary.deleteImageByUrl(p.imageUrl)));
    return { deleted: true };
  }

  // --- Photos ------------------------------------------------------------

  async addPhoto(acting: ActingFor, owner: { ownTestId: string } | { recordPrescriptionId: string }, buffer: Buffer, filename: string) {
    const where = 'ownTestId' in owner ? { ownTestId: owner.ownTestId } : { recordPrescriptionId: owner.recordPrescriptionId };
    const parent =
      'ownTestId' in owner
        ? await this.prisma.ownTest.findUnique({ where: { id: owner.ownTestId }, select: { userId: true } })
        : await this.prisma.recordPrescription.findUnique({ where: { id: owner.recordPrescriptionId }, select: { userId: true } });
    if (!parent || parent.userId !== acting.subjectId) throw new NotFoundException('Record not found');
    const count = await this.prisma.recordPhoto.count({ where });
    if (count >= MAX_PHOTOS) throw new BadRequestException(`Up to ${MAX_PHOTOS} pages`);
    const imageUrl = await this.cloudinary.uploadPrivateImage(buffer, filename, 'records');
    const row = await this.prisma.recordPhoto.create({ data: { userId: acting.subjectId, ...where, imageUrl, page: count + 1 } });
    if (acting.byCaregiver) {
      await this.audit.record({
        actorId: acting.actorId,
        subjectUserId: acting.subjectId,
        action: 'record.photo_add',
        entityType: 'record_photo',
        entityId: row.id,
        after: { byCaregiver: true },
      });
    }
    return this.presentPhoto(row);
  }

  async deletePhoto(acting: ActingFor, id: string) {
    const row = await this.prisma.recordPhoto.findUnique({ where: { id } });
    if (!row || row.userId !== acting.subjectId) throw new NotFoundException('Photo not found');
    await this.prisma.recordPhoto.delete({ where: { id } });
    await this.cloudinary.deleteImageByUrl(row.imageUrl);
    return { deleted: true };
  }

  // --- helpers -----------------------------------------------------------

  private async checkCondition(code: string | null | undefined) {
    if (!code) return;
    if (!(await this.prisma.condition.findUnique({ where: { code } }))) throw new BadRequestException('Unknown condition');
  }

  /** null = no change asked; otherwise the doctor fields to write. */
  private async doctorChoice(userId: string, dto: { doctorId?: string | null; myDoctorId?: string | null; newDoctor?: NewDoctorDto }) {
    const picked = [dto.doctorId, dto.myDoctorId, dto.newDoctor].filter((v) => v != null).length;
    if (picked > 1) throw new BadRequestException('Pick one doctor');
    if (dto.doctorId) {
      if (!(await this.prisma.doctor.findUnique({ where: { id: dto.doctorId }, select: { id: true } }))) {
        throw new BadRequestException('Unknown doctor');
      }
      return { doctorId: dto.doctorId };
    }
    if (dto.myDoctorId) {
      const mine = await this.prisma.myDoctor.findUnique({ where: { id: dto.myDoctorId }, select: { userId: true } });
      if (!mine || mine.userId !== userId) throw new BadRequestException('Unknown doctor');
      return { myDoctorId: dto.myDoctorId };
    }
    if (dto.newDoctor) return { newDoctor: dto.newDoctor };
    // Both sent as null = remove the doctor.
    if (dto.doctorId === null || dto.myDoctorId === null) return { none: true as const };
    return null;
  }

  private async resolveDoctor(
    tx: Prisma.TransactionClient,
    userId: string,
    choice: { doctorId?: string; myDoctorId?: string; newDoctor?: NewDoctorDto; none?: true } | null,
  ) {
    if (!choice || choice.none) return { doctorId: null, myDoctorId: null };
    if (choice.doctorId) return { doctorId: choice.doctorId, myDoctorId: null };
    if (choice.myDoctorId) return { doctorId: null, myDoctorId: choice.myDoctorId };
    const d = choice.newDoctor!;
    // Reuse one of mine with the same name instead of a duplicate.
    const existing = await tx.myDoctor.findFirst({ where: { userId, name: { equals: d.name, mode: 'insensitive' } } });
    const mine =
      existing ??
      (await tx.myDoctor.create({ data: { userId, name: d.name, chamber: d.chamber || null, area: d.area || null } }));
    return { doctorId: null, myDoctorId: mine.id };
  }

  private presentDoctor(r: WithDoctor) {
    if (r.doctor) return { source: 'CATALOG' as const, ...presentCatalogDoctor(r.doctor) };
    if (r.myDoctor) return { source: 'MINE' as const, id: r.myDoctor.id, name: r.myDoctor.name, chamber: r.myDoctor.chamber, area: r.myDoctor.area };
    return null;
  }

  private presentAppointment(a: Prisma.AppointmentGetPayload<{ include: typeof DOCTOR_INCLUDE }>) {
    return {
      id: a.id,
      kind: a.kind,
      date: isoDay(a.date),
      time: a.time,
      doctor: this.presentDoctor(a),
      conditionCode: a.conditionCode,
      number: a.number,
      note: a.note,
      remind: a.remind,
      done: a.doneAt != null,
      doneAt: a.doneAt,
      byCaregiver: Boolean(a.createdById && a.createdById !== a.userId),
      createdAt: a.createdAt,
    };
  }

  private presentTest(t: Prisma.OwnTestGetPayload<{ include: typeof TEST_INCLUDE }>) {
    return {
      id: t.id,
      testKindCode: t.testKind?.code ?? null,
      otherName: t.otherName,
      status: t.status,
      date: isoDay(t.date),
      remind: t.remind,
      fasting: t.fasting,
      findings: t.findings,
      lab: t.lab,
      conditionCode: t.conditionCode,
      healthReminderId: t.healthReminderId,
      values: t.values.map((v) => ({ id: v.id, fieldId: v.fieldId, name: v.name, value: v.value, textValue: v.textValue, unit: v.unit })),
      photos: t.photos.map((p) => this.presentPhoto(p)),
      byCaregiver: Boolean(t.createdById && t.createdById !== t.userId),
      createdAt: t.createdAt,
    };
  }

  private presentPrescription(p: Prisma.RecordPrescriptionGetPayload<{ include: typeof DOCTOR_INCLUDE & { photos: true } }>) {
    return {
      id: p.id,
      date: isoDay(p.date),
      doctor: this.presentDoctor(p),
      conditionCode: p.conditionCode,
      note: p.note,
      photos: p.photos.map((ph) => this.presentPhoto(ph)),
      byCaregiver: Boolean(p.createdById && p.createdById !== p.userId),
      createdAt: p.createdAt,
    };
  }

  /** Never the stored reference: a 1-hour signed link. */
  private presentPhoto(p: Photo) {
    return { id: p.id, page: p.page, imageUrl: this.cloudinary.signedImageUrl(p.imageUrl) };
  }

  private async audited(
    tx: Prisma.TransactionClient,
    acting: ActingFor,
    action: string,
    entityType: string,
    entityId: string,
    after: Record<string, unknown>,
  ) {
    if (!acting.byCaregiver) return;
    await this.audit.record(
      { actorId: acting.actorId, subjectUserId: acting.subjectId, action, entityType, entityId, after: { ...after, byCaregiver: true } as Prisma.InputJsonValue },
      tx,
    );
  }

  private tellMember(acting: ActingFor, key: string) {
    return this.caregivers.notifyMember(acting, 'health_updated', key);
  }
}

function presentCatalogDoctor(d: WithDoctor['doctor'] & object) {
  return { id: d.id, name: d.name, chamber: d.chamber, specialty: d.specialty?.name ?? null, district: d.district?.name ?? null };
}
