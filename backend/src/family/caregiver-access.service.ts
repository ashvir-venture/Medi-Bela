import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { AccountStatus, FamilyRole, NotificationType, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CaregiverAction, messages } from '../notifications/notification-messages';

/** Who a request acts for. `byCaregiver` = the caller acts for another member. */
export interface ActingFor {
  actorId: string;
  subjectId: string;
  byCaregiver: boolean;
}

/**
 * The one place that decides whether the caller may act for another user
 * (`?forUserId=`). Allowed only for the CAREGIVER of the family the target
 * belongs to, and only while the target doesn't hide from family. Anything
 * else is the same 404 as a nonexistent user, so ids can't be probed.
 */
@Injectable()
export class CaregiverAccessService {
  private readonly logger = new Logger(CaregiverAccessService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async resolve(actorId: string, forUserId?: string | null): Promise<ActingFor> {
    if (!forUserId || forUserId === actorId) {
      return { actorId, subjectId: actorId, byCaregiver: false };
    }
    const actor = await this.prisma.familyMember.findUnique({
      where: { userId: actorId },
      select: { familyId: true, role: true },
    });
    if (actor?.role === FamilyRole.CAREGIVER) {
      const target = await this.prisma.familyMember.findFirst({
        where: { familyId: actor.familyId, userId: forUserId },
        select: {
          user: { select: { profileVisibleToFamily: true, role: true, accountStatus: true } },
        },
      });
      if (
        target &&
        target.user.profileVisibleToFamily &&
        target.user.role === Role.USER &&
        target.user.accountStatus === AccountStatus.ACTIVE
      ) {
        return { actorId, subjectId: forUserId, byCaregiver: true };
      }
    }
    throw new NotFoundException('Family member not found');
  }

  /**
   * Tells the member their caregiver did something for them (push + Family
   * inbox tab). Neutral text: no medicine names. `key` makes it idempotent
   * per action (e.g. one push per dose). Never fails the action itself.
   */
  async notifyMember(acting: ActingFor, action: CaregiverAction, key: string) {
    if (!acting.byCaregiver) return;
    try {
      const member = await this.prisma.user.findUnique({
        where: { id: acting.subjectId },
        select: { languagePreference: true },
      });
      if (!member) return;
      const copy = messages.caregiverAction(member.languagePreference, action);
      await this.notifications.notify([
        {
          userId: acting.subjectId,
          type: NotificationType.SYSTEM,
          title: copy.title,
          body: copy.body,
          relatedEntityId: `caregiver:${action}:${key}`,
          data: { kind: 'caregiver_action', action },
        },
      ]);
    } catch (err) {
      this.logger.warn(`Caregiver notification failed: ${(err as Error).message}`);
    }
  }
}
