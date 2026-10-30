import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AccountStatus, PrescriptionStatus, Role, User } from '@prisma/client';
import * as argon2 from 'argon2';
import { randomBytes } from 'crypto';
import { LoginThrottle } from '../auth/login-throttle';
import { AuditService } from '../audit/audit.service';
import { FamilyMembershipService } from '../family/family-membership.service';
import { pauseSchedules } from '../medicine-schedule/rolling-dose.job';
import { NotificationsService } from '../notifications/notifications.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { PrismaService } from '../prisma/prisma.service';
import { sanitizeUser, SafeUser } from '../common/utils/sanitize-user';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DELETED_USER_NAME } from './lib/deleted-user';
import { assertValidDetails, dateOfBirthColumn } from './lib/profile-details';

@Injectable()
export class UsersService {
  private readonly passwordThrottle = new LoginThrottle(); // wrong-password attempts (deactivate / delete), by user

  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinary: CloudinaryService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly family: FamilyMembershipService,
  ) {}

  async getById(userId: string): Promise<SafeUser> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return sanitizeUser(user);
  }

  async updateProfile(
    userId: string,
    dto: UpdateProfileDto,
  ): Promise<SafeUser> {
    await assertValidDetails(this.prisma, dto);
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { ...dto, dateOfBirth: dateOfBirthColumn(dto.dateOfBirth) },
    });
    return sanitizeUser(user);
  }

  /**
   * Internal lookup used by other modules (e.g. Family) to resolve a phone
   * number to a user. Not exposed directly as a controller route to avoid
   * turning it into a phone-number enumeration endpoint.
   */
  findByPhone(phone: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  /**
   * Pauses the caller's own account until they sign in again: every session
   * ends (passwordChangedAt), future doses are removed and generation stops,
   * nothing is pushed, and family sees "Account paused". Login or an SMS
   * reset reactivates it (AuthService).
   */
  async deactivate(userId: string, password: string): Promise<void> {
    await this.reauthenticate(userId, password);
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { accountStatus: AccountStatus.DEACTIVATED, deactivatedAt: now, passwordChangedAt: now },
      });
      await pauseSchedules(tx, userId, now);
      await this.audit.record(
        { actorId: userId, subjectUserId: userId, action: 'user.deactivate', entityType: 'user', entityId: userId },
        tx,
      );
    });
    await this.notifications.endSessions(userId);
  }

  /**
   * Deletes the caller's own account by de-identifying it (the row stays so
   * prescriptions, routines, doses and patient counts keep their patient).
   * Erased: phone, password, name, address, date of birth (the year is kept
   * for age bands), upazila, health records, health reminders, AI health
   * suggestions, assistant conversations, notifications, device tokens, the
   * reset code, family membership and invitations. Kept: prepared
   * prescriptions and their history, gender, birth year, division, district,
   * audit rows. Prescriptions still waiting (PENDING / AWAITING_CONFIRMATION)
   * are deleted; photos of all of them are erased. Nothing can be restored;
   * the phone number is free for a new account. Backups and provider logs are
   * outside the app database and are not touched.
   */
  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await this.reauthenticate(userId, password);
    const now = new Date();
    const images = await this.prisma.prescription.findMany({
      where: { userId, imageUrl: { not: null } },
      select: { imageUrl: true },
    });
    const unusableHash = await argon2.hash(randomBytes(32).toString('hex'));

    const departure = await this.prisma.$transaction(async (tx) => {
      const outcome = await this.family.depart(tx, userId, 'LEFT', userId);
      // Every invitation they sent, and any still addressed to their number.
      await tx.familyInvitation.deleteMany({
        where: { OR: [{ invitedById: userId }, ...(user.phone ? [{ invitedPhone: user.phone }] : [])] },
      });

      await pauseSchedules(tx, userId, now);
      await tx.medicineDose.deleteMany({ where: { userId, status: 'PENDING', scheduledAt: { gt: now } } });
      await tx.medicineRoutine.updateMany({ where: { userId, active: true }, data: { active: false } });
      await tx.prescription.deleteMany({
        where: {
          userId,
          status: { in: [PrescriptionStatus.PENDING, PrescriptionStatus.AWAITING_CONFIRMATION] },
        },
      });
      await tx.prescription.updateMany({ where: { userId }, data: { imageUrl: null } });

      await tx.healthRecord.deleteMany({ where: { userId } });
      await tx.healthReminder.deleteMany({ where: { userId } });
      await tx.healthSuggestion.deleteMany({ where: { userId } });
      await tx.assistantConversation.deleteMany({ where: { userId } });
      await tx.notification.deleteMany({ where: { userId } });
      await tx.passwordResetCode.deleteMany({ where: { userId } });

      await tx.user.update({
        where: { id: userId },
        data: {
          phone: null,
          passwordHash: unusableHash,
          name: DELETED_USER_NAME,
          address: null,
          birthYear: user.dateOfBirth ? user.dateOfBirth.getUTCFullYear() : user.birthYear,
          dateOfBirth: null,
          upazilaId: null,
          notificationsEnabled: false,
          medicineRemindersEnabled: false,
          noticesEnabled: false,
          accountStatus: AccountStatus.DELETED,
          deletedAt: now,
          passwordChangedAt: now,
        },
      });
      // No personal data in the audit row.
      await this.audit.record(
        { actorId: userId, subjectUserId: userId, action: 'user.delete', entityType: 'user', entityId: userId },
        tx,
      );
      return outcome;
    });

    this.passwordThrottle.reset(userId);
    await this.notifications.endSessions(userId);
    await this.family.notifyAfterCommit(departure);
    await Promise.all(images.map((i) => this.cloudinary.deleteImageByUrl(i.imageUrl!)));
  }

  /** Patients only; the current password, throttled per user. */
  private async reauthenticate(userId: string, password: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.role !== Role.USER) {
      throw new ForbiddenException('Staff accounts cannot be changed from the app');
    }
    if (this.passwordThrottle.isBlocked(userId)) {
      throw new HttpException('Too many attempts. Please try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    if (!(await argon2.verify(user.passwordHash, password))) {
      this.passwordThrottle.recordFailure(userId);
      // 403, not 401: the app treats any 401 as "session expired" and logs the user out.
      throw new ForbiddenException('Password is incorrect');
    }
    return user;
  }
}
