import { ConflictException, Injectable, Logger, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { Prisma, SuggestionStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { ErrorCode, withCode } from '../common/filters/error-codes';
import { ADMIN_PAGE_SIZE, CURSOR_ORDER, cursorWhere, toCursorPage } from '../common/utils/cursor-pagination';
import { AiSuggestionService } from './ai-suggestion.service';
import { UpdateHealthSuggestionDto } from './dto/update-health-suggestion.dto';
import { HealthSuggestionListQueryDto, RoutineListQueryDto } from './dto/pharmacist-list-query.dto';

const SAFE_USER_SELECT = { id: true, name: true, phone: true } as const;

/** Medicine / patient name or phone, contains, ignoring case. */
function patientOrText(field: 'medicineName' | 'sourceMedicines', q?: string) {
  if (!q) return {};
  return {
    OR: [
      { [field]: { contains: q, mode: 'insensitive' as const } },
      { user: { name: { contains: q, mode: 'insensitive' as const } } },
      { user: { phone: { contains: q } } },
    ],
  };
}

/**
 * Owns the review/publish lifecycle for AI-generated `HealthSuggestion`
 * rows. Nothing is generated automatically: a pharmacist asks for a
 * suggestion for ONE routine (`requestForRoutine`), reviews the response,
 * and only then chooses to publish it. The AI only ever produces a DRAFT --
 * nothing is visible to the user (`/health-suggestions/mine`) until a
 * pharmacist explicitly publishes it, optionally after editing. Request,
 * edit, publish and unpublish are audited (ids and status only).
 */
@Injectable()
export class HealthSuggestionsService {
  private readonly logger = new Logger(HealthSuggestionsService.name);
  /** Routines with a paid model call running on this instance (stops a double-click paying twice). */
  private readonly inFlight = new Set<string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiSuggestion: AiSuggestionService,
    private readonly audit: AuditService,
  ) {}

  // --- Pharmacist: routine panel ---------------------------------------

  /** Routines across users, newest first, 20 per page, each with its latest suggestion (if any). */
  async listRoutines(query: RoutineListQueryDto = {}) {
    const where: Prisma.MedicineRoutineWhereInput = {
      ...(query.active ? { active: true } : {}),
      ...patientOrText('medicineName', query.q),
    };
    const rows = await this.prisma.medicineRoutine.findMany({
      where: { AND: [where, cursorWhere(query.cursor)] },
      orderBy: CURSOR_ORDER,
      take: ADMIN_PAGE_SIZE + 1,
      include: {
        user: { select: SAFE_USER_SELECT },
        healthSuggestions: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { id: true, status: true, createdAt: true },
        },
      },
    });
    return toCursorPage(rows, ADMIN_PAGE_SIZE);
  }

  async getRoutine(routineId: string) {
    const routine = await this.prisma.medicineRoutine.findUnique({
      where: { id: routineId },
      include: {
        user: { select: SAFE_USER_SELECT },
        prescriptionMedicine: { select: { instructions: true, duration: true } },
        healthSuggestions: {
          orderBy: { createdAt: 'desc' },
          include: { publishedBy: { select: { id: true, name: true } } },
        },
      },
    });
    if (!routine) throw new NotFoundException('Routine not found');
    return routine;
  }

  /**
   * Pharmacist-initiated, one routine, one model call. On success returns the
   * routine's DRAFT (a previous unpublished draft for the same routine is
   * replaced rather than piling up; published suggestions are never touched).
   * On failure nothing is stored and the pharmacist can simply try again.
   */
  async requestForRoutine(actorId: string, routineId: string) {
    const routine = await this.prisma.medicineRoutine.findUnique({
      where: { id: routineId },
      select: { id: true, userId: true, medicineName: true, dosage: true },
    });
    if (!routine) throw new NotFoundException('Routine not found');
    if (!this.aiSuggestion.isConfigured()) {
      throw withCode(new ServiceUnavailableException('AI suggestions are not configured'), ErrorCode.AI_UNAVAILABLE);
    }
    if (this.inFlight.has(routineId)) {
      throw new ConflictException('A suggestion is already being generated for this routine');
    }

    const medicine = `${routine.medicineName} ${routine.dosage}`.replace(/\s+/g, ' ').trim().slice(0, 100);
    this.inFlight.add(routineId);
    try {
      const generated = await this.aiSuggestion.generate([medicine]);
      if (!generated) {
        throw withCode(
          new ServiceUnavailableException('The AI could not produce a suggestion. Please try again.'),
          ErrorCode.AI_UNAVAILABLE,
        );
      }

      const data = { itemsEn: generated.en as any, itemsBn: generated.bn as any, sourceMedicines: medicine };
      const draft = await this.prisma.healthSuggestion.findFirst({
        where: { routineId, status: SuggestionStatus.DRAFT },
        select: { id: true },
      });
      const saved = draft
        ? await this.prisma.healthSuggestion.update({ where: { id: draft.id }, data })
        : await this.prisma.healthSuggestion.create({
            data: { ...data, userId: routine.userId, routineId, status: SuggestionStatus.DRAFT },
          });
      await this.audit.record(this.entry(actorId, { id: saved.id, userId: routine.userId }, 'health_suggestion.request'));
      return this.getDetail(saved.id);
    } finally {
      this.inFlight.delete(routineId);
    }
  }

  // --- Pharmacist ------------------------------------------------------

  /** Newest first, 20 per page; filter by status and medicine / patient. */
  async list(query: HealthSuggestionListQueryDto = {}) {
    const where: Prisma.HealthSuggestionWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...patientOrText('sourceMedicines', query.q),
    };
    const rows = await this.prisma.healthSuggestion.findMany({
      where: { AND: [where, cursorWhere(query.cursor)] },
      orderBy: CURSOR_ORDER,
      take: ADMIN_PAGE_SIZE + 1,
      include: { user: { select: SAFE_USER_SELECT }, publishedBy: { select: { id: true, name: true } } },
    });
    return toCursorPage(rows, ADMIN_PAGE_SIZE);
  }

  async listForUser(userId: string) {
    return this.prisma.healthSuggestion.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getDetail(id: string) {
    const suggestion = await this.prisma.healthSuggestion.findUnique({
      where: { id },
      include: {
        user: { select: SAFE_USER_SELECT },
        publishedBy: { select: { id: true, name: true } },
        routine: { select: { id: true, medicineName: true, dosage: true } },
      },
    });
    if (!suggestion) throw new NotFoundException('Suggestion not found');
    return suggestion;
  }

  /** The pharmacist edits the draft's content before publishing. */
  async update(actorId: string, id: string, dto: UpdateHealthSuggestionDto) {
    const current = await this.getDetail(id);
    return this.prisma.$transaction(async (tx) => {
      const saved = await tx.healthSuggestion.update({
        where: { id },
        data: { itemsEn: dto.itemsEn as any, itemsBn: dto.itemsBn as any },
      });
      await this.audit.record(this.entry(actorId, current, 'health_suggestion.update'), tx);
      return saved;
    });
  }

  async publish(actorId: string, id: string) {
    const current = await this.getDetail(id);
    return this.setStatus(actorId, current, 'health_suggestion.publish', {
      status: SuggestionStatus.PUBLISHED,
      publishedById: actorId,
      publishedAt: new Date(),
    });
  }

  async unpublish(actorId: string, id: string) {
    const current = await this.getDetail(id);
    return this.setStatus(actorId, current, 'health_suggestion.unpublish', {
      status: SuggestionStatus.DRAFT,
      publishedById: null,
      publishedAt: null,
    });
  }

  private setStatus(
    actorId: string,
    current: { id: string; userId: string; status: SuggestionStatus },
    action: string,
    data: Prisma.HealthSuggestionUncheckedUpdateInput & { status: SuggestionStatus },
  ) {
    return this.prisma.$transaction(async (tx) => {
      const saved = await tx.healthSuggestion.update({ where: { id: current.id }, data });
      await this.audit.record(
        { ...this.entry(actorId, current, action), before: { status: current.status }, after: { status: data.status } },
        tx,
      );
      return saved;
    });
  }

  /** Audit rows carry ids and status only, never the suggestion text. */
  private entry(actorId: string, suggestion: { id: string; userId: string }, action: string) {
    return { actorId, subjectUserId: suggestion.userId, action, entityType: 'health_suggestion', entityId: suggestion.id };
  }

  // --- User-facing -----------------------------------------------------

  /** Only ever returns PUBLISHED suggestions -- drafts are never exposed here. */
  async getMine(userId: string) {
    return this.prisma.healthSuggestion.findMany({
      where: { userId, status: SuggestionStatus.PUBLISHED },
      orderBy: { publishedAt: 'desc' },
    });
  }

}
