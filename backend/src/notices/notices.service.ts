import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AccountStatus, Notice, NoticeAudience, NoticeStatus, NotificationType, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { AuditService } from '../audit/audit.service';
import { CreateNoticeDto } from './dto/create-notice.dto';
import { UpdateNoticeDto } from './dto/update-notice.dto';

const ADMIN_INCLUDE = {
  createdBy: { select: { id: true, name: true } },
  approvedBy: { select: { id: true, name: true } },
  divisions: { include: { division: true } },
} as const;

/** What a user's app receives: no workflow or staff details. */
const USER_SELECT = {
  id: true,
  title: true,
  content: true,
  source: true,
  publishedAt: true,
  expiresAt: true,
} as const;

/** Statuses a pharmacist may still change (their own working copy). */
const PHARMACIST_EDITABLE: NoticeStatus[] = [NoticeStatus.DRAFT];

function parseDate(value: string | null | undefined): Date | null | undefined {
  if (value === undefined) return undefined;
  return value === null ? null : new Date(value);
}

/**
 * Government/admin notices.
 *
 *   DRAFT --submit (pharmacist)--> PENDING_APPROVAL --approve (admin)--> PUBLISHED
 *     ^                                 |   |
 *     +---- withdraw (pharmacist) ------+   +-- send back with a note (admin) --> DRAFT
 *   DRAFT --publish (admin, their own or anyone's)--> PUBLISHED
 *   PUBLISHED <--> ARCHIVED (admin)
 *
 * A published notice with a future `startsAt` is scheduled: it has no
 * `publishedAt` yet, is hidden from users, and [goLive] (NoticeScheduleJob)
 * publishes and pushes it when the time comes. `divisions` limits who sees
 * and gets it (none = nationwide); the list and the push use the same rule.
 */
@Injectable()
export class NoticesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditService,
  ) {}

  // --- Staff -----------------------------------------------------------

  async listForAdmin() {
    return this.prisma.notice.findMany({
      orderBy: { createdAt: 'desc' },
      include: ADMIN_INCLUDE,
    });
  }

  async getDetail(id: string) {
    const notice = await this.prisma.notice.findUnique({ where: { id }, include: ADMIN_INCLUDE });
    if (!notice) throw new NotFoundException('Notice not found');
    return notice;
  }

  async create(actorId: string, dto: CreateNoticeDto) {
    await this.assertDivisions(dto.divisionIds);
    const notice = await this.prisma.notice.create({
      data: {
        title: dto.title,
        content: dto.content,
        audience: dto.audience,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        source: dto.source?.trim() || null,
        sourceUrl: dto.sourceUrl || null,
        status: NoticeStatus.DRAFT,
        createdById: actorId,
        divisions: dto.divisionIds?.length
          ? { create: [...new Set(dto.divisionIds)].map((divisionId) => ({ divisionId })) }
          : undefined,
      },
    });
    return this.getDetail(notice.id);
  }

  /** Pharmacists edit only drafts; admins edit any notice. */
  async update(id: string, actor: { id: string; role: Role }, dto: UpdateNoticeDto) {
    const notice = await this.getDetail(id);
    this.assertPharmacistMayChange(notice, actor.role);
    await this.assertDivisions(dto.divisionIds);
    await this.prisma.$transaction(async (tx) => {
      await tx.notice.update({
        where: { id },
        data: {
          title: dto.title,
          content: dto.content,
          audience: dto.audience,
          // null clears; undefined leaves untouched.
          expiresAt: parseDate(dto.expiresAt),
          startsAt: parseDate(dto.startsAt),
          source: dto.source === undefined ? undefined : dto.source?.trim() || null,
          sourceUrl: dto.sourceUrl === undefined ? undefined : dto.sourceUrl || null,
        },
      });
      if (dto.divisionIds) {
        await tx.noticeDivision.deleteMany({ where: { noticeId: id } });
        if (dto.divisionIds.length) {
          await tx.noticeDivision.createMany({
            data: [...new Set(dto.divisionIds)].map((divisionId) => ({ noticeId: id, divisionId })),
          });
        }
      }
    });
    return this.getDetail(id);
  }

  /** Pharmacist: DRAFT -> PENDING_APPROVAL (clears any earlier review note). */
  async submit(id: string, actorId: string) {
    return this.transition(id, actorId, NoticeStatus.DRAFT, NoticeStatus.PENDING_APPROVAL, 'notice.submit', {
      reviewNote: null,
    });
  }

  /** Pharmacist: pull a pending notice back to draft before an admin acts. */
  async withdraw(id: string, actorId: string) {
    return this.transition(id, actorId, NoticeStatus.PENDING_APPROVAL, NoticeStatus.DRAFT, 'notice.withdraw');
  }

  /** Admin: return a pending notice to the pharmacist with a note. */
  async sendBack(id: string, actorId: string, note: string) {
    return this.transition(id, actorId, NoticeStatus.PENDING_APPROVAL, NoticeStatus.DRAFT, 'notice.send_back', {
      reviewNote: note,
    });
  }

  /**
   * Admin: publish a draft (their own or anyone's), approve a pending one,
   * or put an archived notice back. Pushes to the audience exactly once,
   * when it first goes live: now, or at `startsAt` for a scheduled notice.
   */
  async publish(id: string, actorId: string) {
    const notice = await this.getDetail(id);
    if (notice.status === NoticeStatus.PUBLISHED) return notice;

    if (notice.status === NoticeStatus.ARCHIVED) {
      // Back on the list; it was pushed when it first went live.
      await this.prisma.notice.update({ where: { id }, data: { status: NoticeStatus.PUBLISHED } });
      return this.getDetail(id);
    }

    const now = new Date();
    const scheduled = notice.startsAt !== null && notice.startsAt > now;
    const claimed = await this.prisma.notice.updateMany({
      where: { id, status: { in: [NoticeStatus.DRAFT, NoticeStatus.PENDING_APPROVAL] } },
      data: {
        status: NoticeStatus.PUBLISHED,
        approvedById: actorId,
        approvedAt: now,
        reviewNote: null,
        publishedAt: scheduled ? null : now,
      },
    });
    if (claimed.count === 1) {
      await this.audit.record({
        actorId,
        action: notice.status === NoticeStatus.PENDING_APPROVAL ? 'notice.approve' : 'notice.publish',
        entityType: 'notice',
        entityId: id,
        before: { status: notice.status },
        after: { status: NoticeStatus.PUBLISHED, scheduledFor: scheduled ? notice.startsAt.toISOString() : null },
      });
      if (!scheduled) await this.pushIfLive(id, now);
    }
    return this.getDetail(id);
  }

  /**
   * Scheduled notices whose start time has come: publish and push them.
   * Compare-and-set on `publishedAt`, so overlapping runs push once.
   * Returns how many went live.
   */
  async goLive(now: Date = new Date()): Promise<number> {
    const due = await this.prisma.notice.findMany({
      where: { status: NoticeStatus.PUBLISHED, publishedAt: null, startsAt: { lte: now } },
      select: { id: true },
      take: 50,
    });
    let live = 0;
    for (const { id } of due) {
      const claimed = await this.prisma.notice.updateMany({
        where: { id, status: NoticeStatus.PUBLISHED, publishedAt: null },
        data: { publishedAt: now },
      });
      if (claimed.count === 1) {
        live += 1;
        await this.pushIfLive(id, now);
      }
    }
    return live;
  }

  async archive(id: string, actorId: string) {
    const notice = await this.getDetail(id);
    await this.prisma.notice.update({ where: { id }, data: { status: NoticeStatus.ARCHIVED } });
    await this.audit.record({
      actorId,
      action: 'notice.archive',
      entityType: 'notice',
      entityId: id,
      before: { status: notice.status },
      after: { status: NoticeStatus.ARCHIVED },
    });
    return this.getDetail(id);
  }

  /** Pharmacists delete only drafts; admins any notice. */
  async remove(id: string, actor: { id: string; role: Role }) {
    const notice = await this.getDetail(id);
    this.assertPharmacistMayChange(notice, actor.role);
    await this.prisma.notice.delete({ where: { id } });
  }

  // --- User-facing -------------------------------------------------------

  /**
   * Live notices for this user: published and gone live, not expired, the
   * audience includes their role, and nationwide or for their division.
   * Staff have no division and see every division's notices.
   */
  async listVisibleTo(userId: string, role: Role) {
    const now = new Date();
    const staff = role === Role.ADMIN || role === Role.PHARMACIST;
    const divisionId = staff
      ? null
      : (await this.prisma.user.findUnique({ where: { id: userId }, select: { divisionId: true } }))?.divisionId ?? null;
    return this.prisma.notice.findMany({
      where: {
        status: NoticeStatus.PUBLISHED,
        publishedAt: { not: null, lte: now },
        audience: { in: [NoticeAudience.ALL, staff ? NoticeAudience.ADMIN : NoticeAudience.USER] },
        // AND, not spread: both conditions use OR and must not overwrite each other.
        AND: [
          { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
          ...(staff ? [] : [this.divisionFilter(divisionId)]),
        ],
      },
      orderBy: { publishedAt: 'desc' },
      select: USER_SELECT,
    });
  }

  // ---------------------------------------------------------------------

  /** Nationwide notices, plus those for this division (if the user has one). */
  private divisionFilter(divisionId: number | null): Prisma.NoticeWhereInput {
    return divisionId === null
      ? { divisions: { none: {} } }
      : { OR: [{ divisions: { none: {} } }, { divisions: { some: { divisionId } } }] };
  }

  private assertPharmacistMayChange(notice: Notice, role: Role) {
    if (role === Role.PHARMACIST && !PHARMACIST_EDITABLE.includes(notice.status)) {
      throw new ForbiddenException(
        notice.status === NoticeStatus.PENDING_APPROVAL
          ? 'Withdraw the notice to draft before changing it'
          : 'Only an admin can change a notice once it is published',
      );
    }
  }

  private async assertDivisions(divisionIds: number[] | undefined) {
    if (!divisionIds?.length) return;
    const ids = [...new Set(divisionIds)];
    const found = await this.prisma.division.count({ where: { id: { in: ids } } });
    if (found !== ids.length) throw new BadRequestException('Unknown division');
  }

  private async transition(
    id: string,
    actorId: string,
    from: NoticeStatus,
    to: NoticeStatus,
    action: string,
    extra: Prisma.NoticeUpdateManyMutationInput = {},
  ) {
    await this.getDetail(id);
    const claimed = await this.prisma.notice.updateMany({
      where: { id, status: from },
      data: { status: to, ...extra },
    });
    if (claimed.count === 0) {
      throw new ConflictException(`This notice is not ${from.toLowerCase().replace('_', ' ')}`);
    }
    await this.audit.record({
      actorId,
      action,
      entityType: 'notice',
      entityId: id,
      before: { status: from },
      after: { status: to },
    });
    return this.getDetail(id);
  }

  /** Push once the notice is live and not expired, to its audience and divisions. */
  private async pushIfLive(id: string, now: Date) {
    const notice = await this.getDetail(id);
    if (notice.expiresAt !== null && notice.expiresAt <= now) return;

    const roles: Role[] =
      notice.audience === NoticeAudience.USER
        ? [Role.USER]
        : notice.audience === NoticeAudience.ADMIN
          ? [Role.ADMIN, Role.PHARMACIST]
          : [Role.USER, Role.ADMIN, Role.PHARMACIST];
    const divisionIds = notice.divisions.map((d) => d.divisionId);

    const recipients = await this.prisma.user.findMany({
      where: {
        accountStatus: AccountStatus.ACTIVE,
        role: { in: roles },
        // Same rule as the list: patients only in the chosen divisions; staff always.
        ...(divisionIds.length
          ? { OR: [{ role: { not: Role.USER } }, { divisionId: { in: divisionIds } }] }
          : {}),
      },
      select: { id: true },
    });
    const copy = messages.notice(notice.title, notice.content);
    // Rows are created now (and are idempotent); actual FCM sends are drained
    // in batches by the push dispatcher job, so a big audience never blocks the admin's request.
    await this.notifications.notify(
      recipients.map((r) => ({
        userId: r.id,
        type: NotificationType.NOTICE,
        title: copy.title,
        body: copy.body,
        relatedEntityId: notice.id,
        data: { noticeId: notice.id },
      })),
    );
  }
}
