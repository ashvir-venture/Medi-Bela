import { Injectable } from '@nestjs/common';
import { AccountStatus, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CURSOR_ORDER, USER_PAGE_SIZE, cursorWhere, toCursorPage } from '../common/utils/cursor-pagination';
import { DELETED_USER_NAME } from '../users/lib/deleted-user';
import { CaregiverAccessService } from './caregiver-access.service';

/**
 * Audit actions a caregiver writes when acting for a member (`?forUserId=`).
 * Pharmacist and admin actions on the same member (prescription.prepare,
 * user.ban, ...) are not caregiver changes and never listed.
 */
export const CAREGIVER_CHANGE_ACTIONS = [
  'prescription.upload',
  'prescription.confirm',
  'prescription.request_edit',
  'routine.create',
  'routine.update',
  'routine.remove',
  'routine.condition',
  'dose.give',
  'user.easy_mode',
  'personal_reminder.create',
  'personal_reminder.update',
  'personal_reminder.remove',
  'medicine_box.save',
  'health_record.create',
  'care.conditions',
  'care.limits',
  'care.log',
  'care.log_delete',
  'care.settings',
  'record.appointment_create',
  'record.appointment_update',
  'record.appointment_delete',
  'record.test_create',
  'record.test_update',
  'record.test_delete',
  'record.prescription_create',
  'record.prescription_update',
  'record.prescription_delete',
  'record.photo_add',
] as const;

/**
 * Round 17 D (owner, 2026-11-12): "Change history" in manage mode. What a
 * caregiver (the current one or an earlier one) changed for a member, read
 * from the audit rows: the caregiver sees it on the member's page, the member
 * under Family. Only the kind of change, who and when (no values, no
 * medicine names: the audit rows hold ids and status only). 10 per page.
 */
@Injectable()
export class ChangeHistoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  /** Changes made for me by a caregiver. */
  mine(userId: string, cursor?: string) {
    return this.list(userId, cursor);
  }

  /** The caregiver's view of a member (404 unless they may act for them). */
  async forMember(actorId: string, memberId: string, cursor?: string) {
    const acting = await this.caregivers.resolve(actorId, memberId);
    return this.list(acting.subjectId, cursor);
  }

  private async list(subjectId: string, cursor?: string) {
    const where: Prisma.AuditLogWhereInput = {
      subjectUserId: subjectId,
      action: { in: [...CAREGIVER_CHANGE_ACTIONS] },
      // Someone else, a patient account (a caregiver), not a staff member.
      actorId: { not: subjectId },
      actor: { role: Role.USER },
      ...cursorWhere(cursor),
    };
    const rows = await this.prisma.auditLog.findMany({
      where,
      orderBy: CURSOR_ORDER,
      take: USER_PAGE_SIZE + 1,
      select: {
        id: true,
        action: true,
        entityType: true,
        createdAt: true,
        actor: { select: { id: true, name: true, accountStatus: true } },
      },
    });
    const page = toCursorPage(rows, USER_PAGE_SIZE);
    return {
      items: page.items.map((r) => {
        const deleted = r.actor?.accountStatus === AccountStatus.DELETED;
        return {
          id: r.id,
          action: r.action,
          entityType: r.entityType,
          createdAt: r.createdAt,
          actor: r.actor ? { id: r.actor.id, name: deleted ? DELETED_USER_NAME : r.actor.name, deleted } : null,
        };
      }),
      nextCursor: page.nextCursor,
    };
  }
}
