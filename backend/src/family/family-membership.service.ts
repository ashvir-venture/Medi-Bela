import { Injectable, Logger } from '@nestjs/common';
import { FamilyEventKind, FamilyRole, InvitationStatus, NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';

/** What changed when someone left; `notifyAfterCommit` sends the pushes. */
export interface DepartureOutcome {
  familyId: string;
  familyRemoved: boolean;
  newCaregiverId: string | null;
  removedUserId: string | null;
}

/**
 * Leaving a family, being removed from it, and the caregiver handover that
 * follows when the caregiver goes. One place, used by FamilyService (leave /
 * remove) and account deletion. Runs inside the caller's transaction;
 * pushes go out only after it commits (`notifyAfterCommit`).
 */
@Injectable()
export class FamilyMembershipService {
  private readonly logger = new Logger(FamilyMembershipService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Removes `userId`'s membership: LEFT (the user left, or deleted the
   * account) or REMOVED (actorId = the caregiver). If they were caregiver,
   * the member with the earliest joinedAt (ties: lowest id) takes over. A
   * family left with no members is removed (its events with it). Returns
   * null when the user is in no family.
   */
  async depart(
    tx: Prisma.TransactionClient,
    userId: string,
    kind: 'LEFT' | 'REMOVED',
    actorId: string,
  ): Promise<DepartureOutcome | null> {
    const membership = await tx.familyMember.findUnique({ where: { userId } });
    if (!membership) return null;
    const { familyId } = membership;

    await tx.familyMember.delete({ where: { id: membership.id } });
    // Pending invitations they sent go with their place in the family.
    await tx.familyInvitation.deleteMany({
      where: { familyId, invitedById: userId, status: InvitationStatus.PENDING },
    });

    const outcome: DepartureOutcome = {
      familyId,
      familyRemoved: false,
      newCaregiverId: null,
      removedUserId: kind === 'REMOVED' ? userId : null,
    };
    const remaining = await tx.familyMember.findMany({
      where: { familyId },
      orderBy: [{ joinedAt: 'asc' }, { id: 'asc' }],
      select: { id: true, userId: true },
    });
    await this.audit.record(
      {
        actorId,
        subjectUserId: userId,
        action: kind === 'LEFT' ? 'family.leave' : 'family.remove',
        entityType: 'family',
        entityId: familyId,
      },
      tx,
    );
    if (remaining.length === 0) {
      await tx.family.delete({ where: { id: familyId } });
      outcome.familyRemoved = true;
      return outcome;
    }

    await tx.familyEvent.create({
      data: {
        familyId,
        kind: kind === 'LEFT' ? FamilyEventKind.LEFT : FamilyEventKind.REMOVED,
        subjectUserId: userId,
        actorUserId: actorId,
      },
    });

    if (membership.role === FamilyRole.CAREGIVER) {
      const next = remaining[0];
      await tx.familyMember.update({ where: { id: next.id }, data: { role: FamilyRole.CAREGIVER } });
      await tx.familyEvent.create({
        data: { familyId, kind: FamilyEventKind.CAREGIVER_CHANGED, subjectUserId: next.userId, actorUserId: null },
      });
      await this.audit.record(
        {
          actorId,
          subjectUserId: next.userId,
          action: 'family.caregiver_change',
          entityType: 'family',
          entityId: familyId,
          before: { caregiverId: userId },
          after: { caregiverId: next.userId },
        },
        tx,
      );
      outcome.newCaregiverId = next.userId;
    }
    return outcome;
  }

  /**
   * Pushes after the change committed: the removed member hears they were
   * removed; on a handover every remaining member hears who the caregiver is
   * now. Joins and leaves appear only in the feed. Never throws.
   */
  async notifyAfterCommit(outcome: DepartureOutcome | null): Promise<void> {
    if (!outcome) return;
    const stamp = Date.now();
    try {
      if (outcome.removedUserId) {
        const user = await this.prisma.user.findUnique({
          where: { id: outcome.removedUserId },
          select: { languagePreference: true },
        });
        if (user) {
          const copy = messages.familyRemoved(user.languagePreference);
          await this.notifications.notify([
            {
              userId: outcome.removedUserId,
              type: NotificationType.SYSTEM,
              title: copy.title,
              body: copy.body,
              relatedEntityId: `family_removed:${outcome.familyId}:${stamp}`,
              data: { kind: 'family_removed' },
            },
          ]);
        }
      }
      if (outcome.newCaregiverId && !outcome.familyRemoved) {
        const [caregiver, members] = await Promise.all([
          this.prisma.user.findUnique({ where: { id: outcome.newCaregiverId }, select: { name: true } }),
          this.prisma.familyMember.findMany({
            where: { familyId: outcome.familyId },
            select: { userId: true, user: { select: { languagePreference: true } } },
          }),
        ]);
        if (caregiver) {
          await this.notifications.notify(
            members.map((m) => {
              const copy = messages.caregiverChanged(m.user.languagePreference, caregiver.name);
              return {
                userId: m.userId,
                type: NotificationType.SYSTEM,
                title: copy.title,
                body: copy.body,
                relatedEntityId: `caregiver_changed:${outcome.familyId}:${stamp}`,
                data: { kind: 'caregiver_changed' },
              };
            }),
          );
        }
      }
    } catch (err) {
      this.logger.warn(`Family push failed: ${(err as Error).message}`);
    }
  }
}
