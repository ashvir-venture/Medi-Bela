import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AccountStatus, DoseStatus, FamilyEventKind, FamilyRole, InvitationStatus, NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { appDayBounds } from '../common/utils/time.util';
import { normalizePhone } from '../common/utils/phone.util';
import { effectiveStatus } from '../medicine-schedule/lib/dose-status.util';
import { CURSOR_ORDER, cursorWhere, toCursorPage, USER_PAGE_SIZE } from '../common/utils/cursor-pagination';
import { DELETED_USER_NAME } from '../users/lib/deleted-user';
import { FamilyMembershipService } from './family-membership.service';
import { CreateFamilyDto } from './dto/create-family.dto';
import { InviteMemberDto } from './dto/invite-member.dto';

const INVITATION_TTL_DAYS = 7;
/** Spam/abuse guard: a caregiver cannot stack unlimited open invitations. */
const MAX_PENDING_INVITATIONS = 20;

/**
 * What the DB read selects for a member. `profileVisibleToFamily` is read ONLY
 * to decide what to reveal — it is never serialized, and neither are password
 * hashes or refresh-token hashes.
 */
const MEMBER_USER_SELECT = {
  id: true,
  name: true,
  phone: true,
  address: true,
  profileVisibleToFamily: true,
  accountStatus: true,
} as const;

/** Deactivated or banned: the family sees "Account paused" and no medicine data. */
function isPaused(status: AccountStatus): boolean {
  return status !== AccountStatus.ACTIVE;
}

type MemberRow = Prisma.FamilyMemberGetPayload<{
  include: { user: { select: typeof MEMBER_USER_SELECT } };
}>;

/** One place decides what a family member may see about another. */
function presentUser(user: MemberRow['user']) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
    // Address is the only optional profile field here; it honours the member's own preference.
    address: user.profileVisibleToFamily ? user.address : null,
    paused: isPaused(user.accountStatus),
  };
}

@Injectable()
export class FamilyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly membership: FamilyMembershipService,
  ) {}

  private getOwnMembership(userId: string) {
    return this.prisma.familyMember.findUnique({ where: { userId } });
  }

  private async requireMembership(userId: string) {
    const membership = await this.getOwnMembership(userId);
    if (!membership) throw new NotFoundException('You are not part of a family yet');
    return membership;
  }

  // ---------------------------------------------------------------------
  // Family + members
  // ---------------------------------------------------------------------

  async createFamily(userId: string, dto: CreateFamilyDto) {
    try {
      const family = await this.prisma.family.create({
        data: {
          name: dto.name,
          members: { create: { userId, role: FamilyRole.CAREGIVER } },
          events: { create: { kind: FamilyEventKind.CREATED, subjectUserId: userId, actorUserId: userId } },
        },
        select: { id: true },
      });
      return this.loadFamily(family.id);
    } catch (err) {
      // Unique(userId) on family_members: concurrent create / already a member.
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ConflictException('You already belong to a family');
      }
      throw err;
    }
  }

  async getMyFamily(userId: string) {
    const membership = await this.requireMembership(userId);
    return this.loadFamily(membership.familyId);
  }

  private async loadFamily(familyId: string) {
    const family = await this.prisma.family.findUnique({
      where: { id: familyId },
      include: {
        members: {
          include: { user: { select: MEMBER_USER_SELECT } },
          orderBy: { joinedAt: 'asc' },
        },
      },
    });
    if (!family) throw new NotFoundException('You are not part of a family yet');
    return {
      id: family.id,
      name: family.name,
      createdAt: family.createdAt,
      members: family.members.map((m) => ({
        id: m.id,
        role: m.role,
        joinedAt: m.joinedAt,
        user: presentUser(m.user),
      })),
    };
  }

  async listMembers(userId: string) {
    const membership = await this.requireMembership(userId);
    const members = await this.prisma.familyMember.findMany({
      where: { familyId: membership.familyId },
      include: { user: { select: MEMBER_USER_SELECT } },
      orderBy: { joinedAt: 'asc' },
    });
    return members.map((m) => ({
      familyMemberId: m.id,
      role: m.role,
      joinedAt: m.joinedAt,
      user: presentUser(m.user),
    }));
  }

  // ---------------------------------------------------------------------
  // Member medicine status
  // ---------------------------------------------------------------------

  /**
   * Today's dose counts for every OTHER member of the caller's family.
   * Members who do not share with family appear with `shared: false` and
   * no health data at all.
   */
  async getMembersStatusSummary(userId: string) {
    const membership = await this.requireMembership(userId);
    const members = await this.prisma.familyMember.findMany({
      where: { familyId: membership.familyId, userId: { not: userId } },
      include: { user: { select: { id: true, name: true, profileVisibleToFamily: true, accountStatus: true } } },
      orderBy: { joinedAt: 'asc' },
    });

    const { start, end } = appDayBounds(new Date());
    const sharingIds = members
      .filter((m) => m.user.profileVisibleToFamily && !isPaused(m.user.accountStatus))
      .map((m) => m.userId);
    const doses = sharingIds.length
      ? await this.prisma.medicineDose.findMany({
          where: { userId: { in: sharingIds }, scheduledAt: { gte: start, lt: end } },
          select: { userId: true, status: true, scheduledAt: true },
        })
      : [];

    return {
      date: start.toISOString(),
      members: members.map((m) => {
        if (isPaused(m.user.accountStatus)) {
          return { userId: m.userId, name: m.user.name, shared: false as const, paused: true };
        }
        if (!m.user.profileVisibleToFamily) {
          return { userId: m.userId, name: m.user.name, shared: false as const, paused: false };
        }
        const mine = doses
          .filter((d) => d.userId === m.userId)
          .map((d) => effectiveStatus(d.status, d.scheduledAt));
        return {
          userId: m.userId,
          name: m.user.name,
          shared: true as const,
          paused: false,
          today: this.summarize(mine),
        };
      }),
    };
  }

  /**
   * Detail for ONE family member. Authorization is by construction:
   * the target must be in the caller's own family (looked up through the
   * caller's membership, never from a client-supplied family id), and a
   * non-member and a nonexistent user are indistinguishable (same 404).
   */
  async getMemberStatus(userId: string, memberUserId: string) {
    const membership = await this.requireMembership(userId);
    const target = await this.prisma.familyMember.findFirst({
      where: { userId: memberUserId, familyId: membership.familyId },
      include: { user: { select: { id: true, name: true, profileVisibleToFamily: true, accountStatus: true } } },
    });
    if (!target) throw new NotFoundException('Family member not found');

    const paused = isPaused(target.user.accountStatus);
    const member = { userId: target.userId, name: target.user.name, paused };
    const isSelf = target.userId === userId;
    if (paused || (!isSelf && !target.user.profileVisibleToFamily)) {
      return { member, shared: false as const, today: null, doses: [] };
    }

    const { start, end } = appDayBounds(new Date());
    const rows = await this.prisma.medicineDose.findMany({
      where: { userId: target.userId, scheduledAt: { gte: start, lt: end } },
      orderBy: { scheduledAt: 'asc' },
      select: {
        scheduledAt: true,
        status: true,
        takenAt: true,
        routine: { select: { medicineName: true } },
      },
    });

    // Data minimisation: name, time and status only — no dosage, no
    // instructions, no prescription, no dose/routine ids.
    const doses = rows.map((d) => ({
      medicineName: d.routine.medicineName,
      scheduledAt: d.scheduledAt,
      status: effectiveStatus(d.status, d.scheduledAt),
      takenAt: d.takenAt,
    }));
    return {
      member,
      shared: true as const,
      today: this.summarize(doses.map((d) => d.status)),
      doses,
    };
  }

  private summarize(statuses: DoseStatus[]) {
    return {
      total: statuses.length,
      taken: statuses.filter((s) => s === DoseStatus.TAKEN).length,
      missed: statuses.filter((s) => s === DoseStatus.MISSED).length,
      pending: statuses.filter((s) => s === DoseStatus.PENDING).length,
    };
  }

  // ---------------------------------------------------------------------
  // Leave, remove, activity feed
  // ---------------------------------------------------------------------

  /** Any member leaves. A caregiver who leaves hands over to the longest-standing member. */
  async leave(userId: string) {
    await this.requireMembership(userId);
    const outcome = await this.prisma.$transaction((tx) => this.membership.depart(tx, userId, 'LEFT', userId));
    await this.membership.notifyAfterCommit(outcome);
  }

  /** The caregiver removes another member (not themself: they use leave). */
  async removeMember(userId: string, memberUserId: string) {
    const own = await this.requireMembership(userId);
    if (own.role !== FamilyRole.CAREGIVER) {
      throw new ForbiddenException('Only the caregiver can remove members');
    }
    if (memberUserId === userId) {
      throw new BadRequestException('Use Leave family to leave');
    }
    const target = await this.prisma.familyMember.findFirst({
      where: { familyId: own.familyId, userId: memberUserId },
      select: { id: true },
    });
    if (!target) throw new NotFoundException('Family member not found');
    const outcome = await this.prisma.$transaction((tx) =>
      this.membership.depart(tx, memberUserId, 'REMOVED', userId),
    );
    await this.membership.notifyAfterCommit(outcome);
  }

  /**
   * The family's activity feed, newest first, 10 per page. Each user shows
   * by current name; `deleted` marks a deleted account (the app shows its own
   * "Deleted user" text). No phone numbers.
   */
  async listEvents(userId: string, cursor?: string) {
    const own = await this.requireMembership(userId);
    const rows = await this.prisma.familyEvent.findMany({
      where: { familyId: own.familyId, ...cursorWhere(cursor) },
      orderBy: CURSOR_ORDER,
      take: USER_PAGE_SIZE + 1,
      include: {
        subject: { select: { id: true, name: true, accountStatus: true } },
        actor: { select: { id: true, name: true, accountStatus: true } },
      },
    });
    const page = toCursorPage(rows, USER_PAGE_SIZE);
    const person = (u: { id: string; name: string; accountStatus: AccountStatus } | null) => {
      if (!u) return null;
      const deleted = u.accountStatus === AccountStatus.DELETED;
      return { id: u.id, name: deleted ? DELETED_USER_NAME : u.name, deleted };
    };
    return {
      items: page.items.map((e) => ({
        id: e.id,
        kind: e.kind,
        createdAt: e.createdAt,
        subject: person(e.subject),
        actor: person(e.actor),
      })),
      nextCursor: page.nextCursor,
    };
  }

  // ---------------------------------------------------------------------
  // Invitations
  // ---------------------------------------------------------------------

  async inviteMember(userId: string, dto: InviteMemberDto) {
    const membership = await this.requireMembership(userId);
    if (membership.role !== FamilyRole.CAREGIVER) {
      throw new ForbiddenException('Only the caregiver can invite members');
    }

    const phone = normalizePhone(dto.phone);
    const inviter = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true, name: true },
    });
    if (!inviter) throw new NotFoundException('User not found');
    if (phone === inviter.phone) throw new BadRequestException('You cannot invite yourself');

    // Only reveals membership of the caller's OWN family.
    const alreadyMember = await this.prisma.familyMember.findFirst({
      where: { familyId: membership.familyId, user: { phone } },
      select: { id: true },
    });
    if (alreadyMember) throw new ConflictException('This person is already a family member');

    const now = new Date();
    // Lapsed invitations must not block a fresh one to the same number.
    await this.prisma.familyInvitation.updateMany({
      where: { familyId: membership.familyId, status: InvitationStatus.PENDING, expiresAt: { lt: now } },
      data: { status: InvitationStatus.EXPIRED },
    });

    const pending = await this.prisma.familyInvitation.findMany({
      where: { familyId: membership.familyId, status: InvitationStatus.PENDING },
      select: { invitedPhone: true },
    });
    if (pending.some((p) => p.invitedPhone === phone)) {
      throw new ConflictException('An invitation to this phone number is already pending');
    }
    if (pending.length >= MAX_PENDING_INVITATIONS) {
      throw new ConflictException('Too many pending invitations. Wait for replies or for them to expire.');
    }

    const expiresAt = new Date(now.getTime() + INVITATION_TTL_DAYS * 86_400_000);
    let invitation;
    try {
      invitation = await this.prisma.familyInvitation.create({
        data: { familyId: membership.familyId, invitedPhone: phone, invitedById: userId, expiresAt },
      });
    } catch (err) {
      // Partial unique index (family, phone) WHERE status = 'PENDING' — concurrent double submit.
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ConflictException('An invitation to this phone number is already pending');
      }
      throw err;
    }

    // The same response whether or not `phone` has an account: this endpoint
    // must not become a "which phone numbers are registered" oracle. If they
    // do have one, tell them (best-effort, never fails the invite).
    const invitee = await this.prisma.user.findUnique({
      where: { phone },
      select: { id: true, languagePreference: true, accountStatus: true },
    });
    if (invitee && invitee.accountStatus === 'ACTIVE') {
      const copy = messages.familyInvitation(invitee.languagePreference, inviter.name);
      await this.notifications.notify([
        {
          userId: invitee.id,
          type: NotificationType.SYSTEM,
          title: copy.title,
          body: copy.body,
          relatedEntityId: invitation.id,
          data: { kind: 'family_invitation' },
        },
      ]);
    }

    return this.presentSent(invitation);
  }

  async listIncomingInvitations(userPhone: string) {
    const phone = normalizePhone(userPhone);
    await this.prisma.familyInvitation.updateMany({
      where: { invitedPhone: phone, status: InvitationStatus.PENDING, expiresAt: { lt: new Date() } },
      data: { status: InvitationStatus.EXPIRED },
    });
    const rows = await this.prisma.familyInvitation.findMany({
      where: { invitedPhone: phone, status: InvitationStatus.PENDING },
      include: {
        family: { select: { id: true, name: true } },
        // The invitee is NOT yet a family member: show who is asking by name only.
        // (Previously this leaked the inviter's phone and address to any invited number.)
        invitedBy: { select: { name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => ({
      id: r.id,
      familyId: r.familyId,
      invitedPhone: r.invitedPhone,
      status: r.status,
      createdAt: r.createdAt,
      expiresAt: r.expiresAt,
      family: r.family,
      invitedBy: { name: r.invitedBy.name },
    }));
  }

  async listSentInvitations(userId: string) {
    const membership = await this.requireMembership(userId);
    if (membership.role !== FamilyRole.CAREGIVER) {
      throw new ForbiddenException('Only the caregiver can view sent invitations');
    }
    const rows = await this.prisma.familyInvitation.findMany({
      where: {
        familyId: membership.familyId,
        status: InvitationStatus.PENDING,
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => this.presentSent(r));
  }

  async acceptInvitation(userId: string, userPhone: string, invitationId: string) {
    const invitation = await this.getOwnedInvitationOrThrow(invitationId, userPhone);

    try {
      return await this.prisma.$transaction(async (tx) => {
        // A user who only created an EMPTY family of their own (sole caregiver, nobody
        // else in it) may still join another one; that empty family is discarded.
        const existing = await tx.familyMember.findUnique({ where: { userId } });
        if (existing) {
          const size = await tx.familyMember.count({ where: { familyId: existing.familyId } });
          if (existing.role === FamilyRole.CAREGIVER && size === 1) {
            await tx.family.delete({ where: { id: existing.familyId } });
          } else {
            throw new ConflictException('You already belong to a family');
          }
        }

        // Compare-and-set: exactly one concurrent accept/decline can win.
        const claimed = await tx.familyInvitation.updateMany({
          where: { id: invitation.id, status: InvitationStatus.PENDING },
          data: { status: InvitationStatus.ACCEPTED, respondedAt: new Date() },
        });
        if (claimed.count === 0) throw new ConflictException('This invitation is no longer pending');

        await tx.familyMember.create({
          data: { familyId: invitation.familyId, userId, role: FamilyRole.MEMBER },
        });
        await tx.familyEvent.create({
          data: { familyId: invitation.familyId, kind: FamilyEventKind.JOINED, subjectUserId: userId, actorUserId: userId },
        });
        return { id: invitation.id, status: InvitationStatus.ACCEPTED };
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ConflictException('You already belong to a family');
      }
      throw err;
    }
  }

  async declineInvitation(userPhone: string, invitationId: string) {
    const invitation = await this.getOwnedInvitationOrThrow(invitationId, userPhone);
    const claimed = await this.prisma.familyInvitation.updateMany({
      where: { id: invitation.id, status: InvitationStatus.PENDING },
      data: { status: InvitationStatus.DECLINED, respondedAt: new Date() },
    });
    if (claimed.count === 0) throw new ConflictException('This invitation is no longer pending');
    return { id: invitation.id, status: InvitationStatus.DECLINED };
  }

  /**
   * Loads an invitation and verifies it was addressed to the caller's phone.
   * Someone else's invitation is a plain 404 (IDOR-safe: existence is not confirmed).
   */
  private async getOwnedInvitationOrThrow(invitationId: string, userPhone: string) {
    const invitation = await this.prisma.familyInvitation.findUnique({ where: { id: invitationId } });
    if (!invitation || invitation.invitedPhone !== normalizePhone(userPhone)) {
      throw new NotFoundException('Invitation not found');
    }
    if (invitation.status === InvitationStatus.PENDING && invitation.expiresAt && invitation.expiresAt < new Date()) {
      await this.prisma.familyInvitation.updateMany({
        where: { id: invitation.id, status: InvitationStatus.PENDING },
        data: { status: InvitationStatus.EXPIRED },
      });
      throw new ConflictException('This invitation has expired');
    }
    if (invitation.status !== InvitationStatus.PENDING) {
      throw new ConflictException(`This invitation is already ${invitation.status.toLowerCase()}`);
    }
    return invitation;
  }

  private presentSent(r: { id: string; familyId: string; invitedPhone: string; status: InvitationStatus; createdAt: Date; expiresAt: Date | null }) {
    return {
      id: r.id,
      familyId: r.familyId,
      invitedPhone: r.invitedPhone,
      status: r.status,
      createdAt: r.createdAt,
      expiresAt: r.expiresAt,
    };
  }
}
