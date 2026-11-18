import { ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { AccountStatus, FamilyRole, Language, NotificationType, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CaregiverAction, messages } from '../notifications/notification-messages';
import { ErrorCode, withCode } from '../common/filters/error-codes';

/** Round 18: a read needs the member's View permission, a change their Manage permission. */
export type CaregiverNeed = 'view' | 'manage';

/** Who a request acts for. `byCaregiver` = the caller acts for another member. */
export interface ActingFor {
  actorId: string;
  subjectId: string;
  byCaregiver: boolean;
}

/**
 * The one place that decides whether the caller may act for another user
 * (`?forUserId=`). Allowed only for the CAREGIVER of the family the target
 * belongs to, only while the target doesn't hide from family, and (Round 18)
 * only with the permission the member gave: View for reads, Manage for
 * changes. Anything else is the same 404 as a nonexistent user, so ids
 * can't be probed.
 */
@Injectable()
export class CaregiverAccessService {
  private readonly logger = new Logger(CaregiverAccessService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async resolve(actorId: string, forUserId?: string | null, need: CaregiverNeed = 'manage'): Promise<ActingFor> {
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
          caregiverCanView: true,
          caregiverCanManage: true,
          user: { select: { profileVisibleToFamily: true, role: true, accountStatus: true } },
        },
      });
      if (
        target &&
        target.user.profileVisibleToFamily &&
        target.user.role === Role.USER &&
        target.user.accountStatus === AccountStatus.ACTIVE
      ) {
        const allowed = need === 'view' ? target.caregiverCanView || target.caregiverCanManage : target.caregiverCanManage;
        if (allowed) return { actorId, subjectId: forUserId, byCaregiver: true };
        // Round 18: their own caregiver is told why (the member decides in Settings);
        // anyone else still gets the same 404 as a nonexistent user.
        throw withCode(new ForbiddenException('This family member has not allowed this'), ErrorCode.CAREGIVER_NO_PERMISSION);
      }
    }
    throw new NotFoundException('Family member not found');
  }

  /**
   * The caregiver of [memberId]'s family who may hear about them: the member
   * shares with family and is active, the caregiver is active and isn't the
   * member. Null otherwise.
   */
  async caregiverOf(memberId: string): Promise<{ id: string; languagePreference: Language; memberName: string } | null> {
    const member = await this.prisma.familyMember.findUnique({
      where: { userId: memberId },
      select: {
        familyId: true,
        user: { select: { name: true, profileVisibleToFamily: true, accountStatus: true } },
      },
    });
    if (!member || !member.user.profileVisibleToFamily || member.user.accountStatus !== AccountStatus.ACTIVE) {
      return null;
    }
    const caregiver = await this.prisma.familyMember.findFirst({
      where: {
        familyId: member.familyId,
        role: FamilyRole.CAREGIVER,
        userId: { not: memberId },
        user: { accountStatus: AccountStatus.ACTIVE },
      },
      select: { user: { select: { id: true, languagePreference: true } } },
    });
    return caregiver ? { ...caregiver.user, memberName: member.user.name } : null;
  }

  /**
   * Tells the member their caregiver did something for them (push + Family
   * inbox tab). Neutral text: no medicine names. `key` makes it idempotent
   * per action (e.g. one push per dose). Never fails the action itself.
   */
  async notifyMember(acting: ActingFor, action: CaregiverAction, key: string, extra?: Record<string, string>) {
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
          // `extra` = ids only (e.g. doseIds, so the member's phone stops ringing for them).
          data: { kind: 'caregiver_action', action, ...extra },
        },
      ]);
    } catch (err) {
      this.logger.warn(`Caregiver notification failed: ${(err as Error).message}`);
    }
  }
}
