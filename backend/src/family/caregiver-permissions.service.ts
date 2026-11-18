import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { AccountStatus, FamilyRole, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { AuditService } from '../audit/audit.service';
import { CaregiverPermissionsDto } from './dto/caregiver-permissions.dto';

export interface CaregiverPermissions {
  /** True when this user is a member (not the caregiver) of a family with a caregiver. */
  applies: boolean;
  view: boolean;
  manage: boolean;
  /** False until the member answers (the app's pop-up asks while false). */
  answered: boolean;
  caregiver: { id: string; name: string } | null;
}

/**
 * Round 18 (owner 2026-11-17): a member decides what the family caregiver
 * may do: View (see medicines, doses, readings, records, prescriptions) and
 * Manage (change them). Both off by default; the app asks right after the
 * member joins (and after a caregiver handover). With both off the caregiver
 * is only notified. CaregiverAccessService enforces it on every request.
 */
@Injectable()
export class CaregiverPermissionsService {
  private readonly logger = new Logger(CaregiverPermissionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditService,
  ) {}

  async get(userId: string): Promise<CaregiverPermissions> {
    const me = await this.prisma.familyMember.findUnique({ where: { userId } });
    const none: CaregiverPermissions = { applies: false, view: false, manage: false, answered: true, caregiver: null };
    if (!me || me.role === FamilyRole.CAREGIVER) return none;
    const caregiver = await this.prisma.familyMember.findFirst({
      where: { familyId: me.familyId, role: FamilyRole.CAREGIVER },
      select: { user: { select: { id: true, name: true } } },
    });
    if (!caregiver) return none;
    return {
      applies: true,
      view: me.caregiverCanView || me.caregiverCanManage,
      manage: me.caregiverCanManage,
      answered: me.caregiverPermissionAt != null,
      caregiver: caregiver.user,
    };
  }

  /** Manage on turns View on; View off turns Manage off. The caregiver is told (neutral text). */
  async set(userId: string, dto: CaregiverPermissionsDto): Promise<CaregiverPermissions> {
    const me = await this.prisma.familyMember.findUnique({ where: { userId }, include: { user: { select: { name: true } } } });
    if (!me || me.role === FamilyRole.CAREGIVER) throw new NotFoundException('You are not a member of a family with a caregiver');
    const manage = dto.manage;
    const view = dto.view || manage;
    const before = { view: me.caregiverCanView || me.caregiverCanManage, manage: me.caregiverCanManage };
    await this.prisma.$transaction(async (tx) => {
      await tx.familyMember.update({
        where: { id: me.id },
        data: { caregiverCanView: view, caregiverCanManage: manage, caregiverPermissionAt: new Date() },
      });
      await this.audit.record(
        {
          actorId: userId,
          subjectUserId: userId,
          action: 'family.permission',
          entityType: 'family_member',
          entityId: me.id,
          before,
          after: { view, manage },
        },
        tx,
      );
    });
    if (before.view !== view || before.manage !== manage) await this.tellCaregiver(me.familyId, userId, me.user.name, view, manage);
    return this.get(userId);
  }

  private async tellCaregiver(familyId: string, memberId: string, memberName: string, view: boolean, manage: boolean) {
    try {
      const caregiver = await this.prisma.familyMember.findFirst({
        where: { familyId, role: FamilyRole.CAREGIVER, userId: { not: memberId }, user: { accountStatus: AccountStatus.ACTIVE } },
        select: { user: { select: { id: true, languagePreference: true } } },
      });
      if (!caregiver) return;
      const copy = messages.caregiverPermissionChanged(caregiver.user.languagePreference, memberName, view, manage);
      await this.notifications.notify([
        {
          userId: caregiver.user.id,
          type: NotificationType.SYSTEM,
          title: copy.title,
          body: copy.body,
          relatedEntityId: `permission:${memberId}:${Date.now()}`,
          data: { kind: 'caregiver_permission', memberId, view: String(view), manage: String(manage) },
        },
      ]);
    } catch (err) {
      this.logger.warn(`Permission notification failed: ${(err as Error).message}`);
    }
  }
}
