import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ADMIN_PAGE_SIZE, CURSOR_ORDER, cursorWhere, toCursorPage } from '../common/utils/cursor-pagination';
import { addAppDays, appUtcOffsetMinutes } from '../common/utils/time.util';
import { AuditLogQueryDto } from './dto/audit-log-query.dto';

/** Names and roles only: the log never shows phone numbers. */
const ROW_SELECT = {
  id: true,
  createdAt: true,
  action: true,
  entityType: true,
  entityId: true,
  actor: { select: { id: true, name: true, role: true } },
  subjectUser: { select: { id: true, name: true } },
} as const;

/** 00:00 (app timezone) of a YYYY-MM-DD day. */
function appDayStart(day: string): Date {
  const utcMidnight = new Date(`${day}T00:00:00.000Z`);
  if (Number.isNaN(utcMidnight.getTime())) throw new BadRequestException('Invalid date');
  return new Date(utcMidnight.getTime() - appUtcOffsetMinutes() * 60_000);
}

/**
 * Admin's read-only view of AuditLog (written by AuditService.record).
 * Keyset pages on (createdAt, id) DESC, 20 rows; before/after only on the
 * detail endpoint.
 */
@Injectable()
export class AuditLogService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: AuditLogQueryDto) {
    const createdAt: Prisma.DateTimeFilter = {};
    if (query.from) createdAt.gte = appDayStart(query.from);
    if (query.to) createdAt.lt = addAppDays(appDayStart(query.to), 1);

    const where: Prisma.AuditLogWhereInput = {
      ...(query.action ? { action: query.action } : {}),
      ...(query.actorId ? { actorId: query.actorId } : {}),
      ...(query.actorRole ? { actor: { role: query.actorRole } } : {}),
      ...(query.from || query.to ? { createdAt } : {}),
    };
    const rows = await this.prisma.auditLog.findMany({
      where: { AND: [where, cursorWhere(query.cursor)] },
      orderBy: CURSOR_ORDER,
      take: ADMIN_PAGE_SIZE + 1,
      select: ROW_SELECT,
    });
    return toCursorPage(rows, ADMIN_PAGE_SIZE);
  }

  /** Choices for the panel's filters: actions seen so far and staff who can act. */
  async filters() {
    const [actions, actors] = await Promise.all([
      this.prisma.auditLog.groupBy({ by: ['action'], orderBy: { action: 'asc' } }),
      this.prisma.user.findMany({
        where: { role: { in: [Role.ADMIN, Role.PHARMACIST] } },
        orderBy: { name: 'asc' },
        select: { id: true, name: true, role: true },
      }),
    ]);
    return { actions: actions.map((a) => a.action), actors };
  }

  async detail(id: string) {
    const row = await this.prisma.auditLog.findUnique({
      where: { id },
      select: { ...ROW_SELECT, before: true, after: true },
    });
    if (!row) throw new NotFoundException('Audit entry not found');
    return row;
  }
}
