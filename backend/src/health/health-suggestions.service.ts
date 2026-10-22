import { ConflictException, Injectable, Logger, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { SuggestionStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AiSuggestionService } from './ai-suggestion.service';
import { UpdateHealthSuggestionDto } from './dto/update-health-suggestion.dto';

const SAFE_USER_SELECT = { id: true, name: true, phone: true } as const;

/**
 * Owns the review/publish lifecycle for AI-generated `HealthSuggestion`
 * rows. Nothing is generated automatically: an admin/pharmacist asks for a
 * suggestion for ONE routine (`requestForRoutine`), reviews the response,
 * and only then chooses to publish it. The AI only ever produces a DRAFT --
 * nothing is visible to the user (`/health-suggestions/mine`) until an
 * admin explicitly publishes it, optionally after editing.
 */
@Injectable()
export class HealthSuggestionsService {
  private readonly logger = new Logger(HealthSuggestionsService.name);
  /** Routines with a paid model call running on this instance (stops a double-click paying twice). */
  private readonly inFlight = new Set<string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiSuggestion: AiSuggestionService,
  ) {}

  // --- Admin: routine panel ------------------------------------------

  /** Routines across users, newest first, each with its latest suggestion (if any). */
  async listRoutinesForAdmin(filter: { userId?: string; active?: boolean } = {}) {
    return this.prisma.medicineRoutine.findMany({
      where: { userId: filter.userId, active: filter.active },
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: {
        user: { select: SAFE_USER_SELECT },
        healthSuggestions: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { id: true, status: true, createdAt: true },
        },
      },
    });
  }

  async getRoutineForAdmin(routineId: string) {
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
   * Admin-initiated, one routine, one model call. On success returns the
   * routine's DRAFT (a previous unpublished draft for the same routine is
   * replaced rather than piling up; published suggestions are never touched).
   * On failure nothing is stored and the admin can simply try again.
   */
  async requestForRoutine(routineId: string) {
    const routine = await this.prisma.medicineRoutine.findUnique({
      where: { id: routineId },
      select: { id: true, userId: true, medicineName: true, dosage: true },
    });
    if (!routine) throw new NotFoundException('Routine not found');
    if (!this.aiSuggestion.isConfigured()) {
      throw new ServiceUnavailableException('AI suggestions are not configured');
    }
    if (this.inFlight.has(routineId)) {
      throw new ConflictException('A suggestion is already being generated for this routine');
    }

    const medicine = `${routine.medicineName} ${routine.dosage}`.replace(/\s+/g, ' ').trim().slice(0, 100);
    this.inFlight.add(routineId);
    try {
      const generated = await this.aiSuggestion.generate([medicine]);
      if (!generated) throw new ServiceUnavailableException('The AI could not produce a suggestion. Please try again.');

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
      return this.getDetail(saved.id);
    } finally {
      this.inFlight.delete(routineId);
    }
  }

  // --- Admin ---------------------------------------------------------

  async listForAdmin() {
    return this.prisma.healthSuggestion.findMany({
      orderBy: { createdAt: 'desc' },
      include: { user: { select: SAFE_USER_SELECT }, publishedBy: { select: { id: true, name: true } } },
    });
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

  /** Admin edits the draft's content before publishing. */
  async update(id: string, dto: UpdateHealthSuggestionDto) {
    await this.getDetail(id);
    return this.prisma.healthSuggestion.update({
      where: { id },
      data: { itemsEn: dto.itemsEn as any, itemsBn: dto.itemsBn as any },
    });
  }

  async publish(adminId: string, id: string) {
    await this.getDetail(id);
    return this.prisma.healthSuggestion.update({
      where: { id },
      data: { status: SuggestionStatus.PUBLISHED, publishedById: adminId, publishedAt: new Date() },
    });
  }

  async unpublish(id: string) {
    await this.getDetail(id);
    return this.prisma.healthSuggestion.update({
      where: { id },
      data: { status: SuggestionStatus.DRAFT, publishedById: null, publishedAt: null },
    });
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
