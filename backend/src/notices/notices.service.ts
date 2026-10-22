import { Injectable, NotFoundException } from '@nestjs/common';
import { AccountStatus, NoticeAudience, NoticeStatus, NotificationType, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { CreateNoticeDto } from './dto/create-notice.dto';
import { UpdateNoticeDto } from './dto/update-notice.dto';

/**
 * Government/admin notices. Same draft-then-publish convention as
 * `HealthSuggestionRule`/`HealthSuggestion`: a notice is never visible
 * to users until an admin explicitly publishes it.
 */
@Injectable()
export class NoticesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // --- Admin -----------------------------------------------------------

  async listForAdmin() {
    return this.prisma.notice.findMany({
      orderBy: { createdAt: 'desc' },
      include: { createdBy: { select: { id: true, name: true } } },
    });
  }

  async getDetail(id: string) {
    const notice = await this.prisma.notice.findUnique({
      where: { id },
      include: { createdBy: { select: { id: true, name: true } } },
    });
    if (!notice) throw new NotFoundException('Notice not found');
    return notice;
  }

  async create(adminId: string, dto: CreateNoticeDto) {
    return this.prisma.notice.create({
      data: {
        title: dto.title,
        content: dto.content,
        audience: dto.audience,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
        status: NoticeStatus.DRAFT,
        createdById: adminId,
      },
    });
  }

  async update(id: string, dto: UpdateNoticeDto) {
    await this.getDetail(id);
    return this.prisma.notice.update({
      where: { id },
      data: {
        title: dto.title,
        content: dto.content,
        audience: dto.audience,
        // null clears the expiry; undefined leaves it untouched.
        expiresAt: dto.expiresAt === null ? null : dto.expiresAt ? new Date(dto.expiresAt) : undefined,
      },
    });
  }

  /**
   * Publishing pushes the notice to its audience exactly once: only the
   * DRAFT -> PUBLISHED transition (won via compare-and-set) fans out.
   * Re-publishing an archived notice, or a repeated publish call, does not push again.
   */
  async publish(id: string) {
    const notice = await this.getDetail(id);
    if (notice.status === NoticeStatus.PUBLISHED) return notice;

    if (notice.status === NoticeStatus.ARCHIVED) {
      return this.prisma.notice.update({ where: { id }, data: { status: NoticeStatus.PUBLISHED } });
    }

    const claimed = await this.prisma.notice.updateMany({
      where: { id, status: NoticeStatus.DRAFT },
      data: { status: NoticeStatus.PUBLISHED, publishedAt: new Date() },
    });
    const published = await this.getDetail(id);

    const alreadyExpired = published.expiresAt !== null && published.expiresAt <= new Date();
    if (claimed.count === 1 && !alreadyExpired) {
      await this.pushToAudience(published);
    }
    return published;
  }

  private async pushToAudience(notice: { id: string; title: string; content: string; audience: NoticeAudience }) {
    const roles: Role[] =
      notice.audience === NoticeAudience.USER
        ? [Role.USER]
        : notice.audience === NoticeAudience.ADMIN
          ? [Role.ADMIN, Role.PHARMACIST]
          : [Role.USER, Role.ADMIN, Role.PHARMACIST];

    const recipients = await this.prisma.user.findMany({
      where: { accountStatus: AccountStatus.ACTIVE, role: { in: roles } },
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

  async archive(id: string) {
    await this.getDetail(id);
    return this.prisma.notice.update({ where: { id }, data: { status: NoticeStatus.ARCHIVED } });
  }

  async remove(id: string) {
    await this.getDetail(id);
    await this.prisma.notice.delete({ where: { id } });
  }

  // --- User-facing -------------------------------------------------------

  /**
   * Only published, non-expired notices whose audience includes this
   * caller's role (ALL, or their exact role).
   */
  async listVisibleTo(role: Role) {
    const now = new Date();
    return this.prisma.notice.findMany({
      where: {
        status: NoticeStatus.PUBLISHED,
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
        audience: { in: ['ALL', role === Role.ADMIN || role === Role.PHARMACIST ? 'ADMIN' : 'USER'] },
      },
      orderBy: { publishedAt: 'desc' },
    });
  }
}
