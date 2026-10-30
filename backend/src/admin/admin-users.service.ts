import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AccountStatus, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { pauseSchedules, resumeSchedules } from '../medicine-schedule/rolling-dose.job';
import { normalizePhone } from '../common/utils/phone.util';
import { appDayBounds, appUtcOffsetMinutes } from '../common/utils/time.util';
import { ADMIN_PAGE_SIZE, CURSOR_ORDER, cursorWhere, toCursorPage } from '../common/utils/cursor-pagination';
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';

const BAND_YEARS: Record<string, [number, number]> = {
  '0-17': [0, 17],
  '18-39': [18, 39],
  '40-59': [40, 59],
  '60+': [60, 200],
};

/** A whole number as typed (01…, 8801…, +8801…); anything shorter is a part. */
const COMPLETE_PHONE = /^(\+?88)?01\d{9}$/;

/**
 * Admin users page: the list with filters, and ban / unban. Admins may ban
 * patients and pharmacists, never an admin (themself included), so the only
 * admin can't lock everyone out. A ban signs the user out everywhere and
 * pauses their reminders like a deactivation; login never lifts it.
 */
@Injectable()
export class AdminUsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
  ) {}

  async list(query: AdminUsersQueryDto) {
    const where: Prisma.UserWhereInput = {
      accountStatus: query.status ?? { not: AccountStatus.DELETED },
      ...(query.role ? { role: query.role } : {}),
      ...(query.divisionId ? { divisionId: query.divisionId } : {}),
    };
    const and: Prisma.UserWhereInput[] = [];
    const phone = query.phone?.trim();
    if (phone) and.push(phoneFilter(phone));
    if (query.ageBand) and.push(ageFilter(query.ageBand, new Date()));
    if (query.cursor) and.push(cursorWhere(query.cursor));
    if (and.length) where.AND = and;

    const rows = await this.prisma.user.findMany({
      where,
      orderBy: CURSOR_ORDER,
      take: ADMIN_PAGE_SIZE + 1,
      select: {
        id: true,
        name: true,
        phone: true,
        role: true,
        accountStatus: true,
        createdAt: true,
        division: { select: { id: true, name: true } },
      },
    });
    const page = toCursorPage(rows, ADMIN_PAGE_SIZE);
    return {
      items: page.items.map((u) => ({ ...u, canBan: u.role !== Role.ADMIN && u.accountStatus !== AccountStatus.DELETED })),
      nextCursor: page.nextCursor,
    };
  }

  async ban(adminId: string, userId: string) {
    const target = await this.requireTarget(userId);
    if (target.accountStatus === AccountStatus.SUSPENDED) throw new ConflictException('This account is already suspended');
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { accountStatus: AccountStatus.SUSPENDED, suspendedAt: now, passwordChangedAt: now },
      });
      await pauseSchedules(tx, userId, now);
      await this.audit.record(
        {
          actorId: adminId,
          subjectUserId: userId,
          action: 'user.ban',
          entityType: 'user',
          entityId: userId,
          before: { accountStatus: target.accountStatus },
          after: { accountStatus: AccountStatus.SUSPENDED },
        },
        tx,
      );
    });
    await this.notifications.endSessions(userId);
    return { id: userId, accountStatus: AccountStatus.SUSPENDED };
  }

  /** Back to ACTIVE (also when the user had deactivated before the ban). */
  async unban(adminId: string, userId: string) {
    const target = await this.requireTarget(userId);
    if (target.accountStatus !== AccountStatus.SUSPENDED) throw new ConflictException('This account is not suspended');
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { accountStatus: AccountStatus.ACTIVE, suspendedAt: null, deactivatedAt: null },
      });
      await this.audit.record(
        {
          actorId: adminId,
          subjectUserId: userId,
          action: 'user.unban',
          entityType: 'user',
          entityId: userId,
          before: { accountStatus: AccountStatus.SUSPENDED },
          after: { accountStatus: AccountStatus.ACTIVE },
        },
        tx,
      );
    });
    await resumeSchedules(this.prisma, userId);
    return { id: userId, accountStatus: AccountStatus.ACTIVE };
  }

  private async requireTarget(userId: string) {
    const target = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, accountStatus: true },
    });
    if (!target || target.accountStatus === AccountStatus.DELETED) throw new NotFoundException('User not found');
    if (target.role === Role.ADMIN) throw new ForbiddenException('Admin accounts cannot be banned');
    return target;
  }
}

/**
 * A complete number matches exactly (as stored: app sign-ups are +880…,
 * seeded staff as typed in .env); a part matches anywhere in the number.
 */
function phoneFilter(raw: string): Prisma.UserWhereInput {
  const typed = raw.replace(/[\s\-().]/g, '');
  if (COMPLETE_PHONE.test(typed)) {
    const normalized = normalizePhone(typed);
    const local = normalized.slice(3); // 01…
    return { phone: { in: [normalized, local, typed] } };
  }
  const digits = typed.replace(/\D/g, '');
  return { phone: { contains: digits || typed } };
}

/** Age on today's app-timezone date: from dateOfBirth, or birthYear when only that is left. */
function ageFilter(band: string, now: Date): Prisma.UserWhereInput {
  const [min, max] = BAND_YEARS[band];
  const today = new Date(appDayBounds(now).start.getTime() + appUtcOffsetMinutes() * 60_000);
  const y = today.getUTCFullYear();
  const m = today.getUTCMonth();
  const d = today.getUTCDate();
  // Born on or before (today - min years) and after (today - (max + 1) years).
  const latest = new Date(Date.UTC(y - min, m, d));
  const earliestExclusive = new Date(Date.UTC(y - max - 1, m, d));
  return {
    OR: [
      { dateOfBirth: { lte: latest, gt: earliestExclusive } },
      { dateOfBirth: null, birthYear: { gte: y - max, lte: y - min } },
    ],
  };
}
