import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Role, User } from '@prisma/client';
import * as argon2 from 'argon2';
import { LoginThrottle } from '../auth/login-throttle';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { PrismaService } from '../prisma/prisma.service';
import { sanitizeUser, SafeUser } from '../common/utils/sanitize-user';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  private readonly deleteThrottle = new LoginThrottle(); // wrong-password attempts, by user

  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinary: CloudinaryService,
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
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: dto,
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
   * Permanently deletes the caller's own account and everything the app holds
   * for it (cascades: prescriptions, routines, doses, reminders, health data,
   * notifications, device tokens, assistant conversations, family membership).
   * Requires the current password. Staff accounts cannot be deleted here.
   * Family invitations the user sent are removed first (their FK is RESTRICT),
   * and a family left with no members is removed. Prescription images are
   * deleted from storage afterwards (best effort). Backups and provider logs
   * are outside the app database and are not touched.
   */
  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.role !== Role.USER) {
      throw new ForbiddenException('Staff accounts cannot be deleted from the app');
    }
    if (this.deleteThrottle.isBlocked(userId)) {
      throw new HttpException('Too many attempts. Please try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    if (!(await argon2.verify(user.passwordHash, password))) {
      this.deleteThrottle.recordFailure(userId);
      // 403, not 401: the app treats any 401 as "session expired" and logs the user out.
      throw new ForbiddenException('Password is incorrect');
    }

    const images = await this.prisma.prescription.findMany({ where: { userId }, select: { imageUrl: true } });

    await this.prisma.$transaction(async (tx) => {
      const membership = await tx.familyMember.findUnique({ where: { userId }, select: { familyId: true } });
      // Invitations this user sent, and any still addressed to their number.
      await tx.familyInvitation.deleteMany({ where: { OR: [{ invitedById: userId }, { invitedPhone: user.phone }] } });
      await tx.user.delete({ where: { id: userId } });
      if (membership) {
        const left = await tx.familyMember.count({ where: { familyId: membership.familyId } });
        if (left === 0) await tx.family.delete({ where: { id: membership.familyId } });
      }
    });

    this.deleteThrottle.reset(userId);
    await Promise.all(images.map((i) => this.cloudinary.deleteImageByUrl(i.imageUrl)));
  }
}
