import {
  ConflictException,
  BadRequestException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma, User } from '@prisma/client';
import * as argon2 from 'argon2';
import { createHmac, randomInt, timingSafeEqual } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from '../common/interfaces/jwt-payload.interface';
import { sanitizeUser, SafeUser } from '../common/utils/sanitize-user';
import { RegisterDto } from './dto/register.dto';
import { assertValidDetails, dateOfBirthColumn } from '../users/lib/profile-details';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ForgotPasswordDto, ResetPasswordDto } from './dto/forgot-password.dto';
import { SmsService } from './sms.service';
import { TokenPair } from './types/tokens.type';
import { LoginThrottle } from './login-throttle';

// Verified against when the phone is unknown, so "no such user" costs the same
// time as "wrong password" (no timing oracle for registered numbers).
const DUMMY_HASH_PROMISE = argon2.hash('carebridge-dummy-password');

const RESET_CODE_TTL_MS = 10 * 60 * 1000;
const RESET_MAX_CODE_ATTEMPTS = 5; // wrong guesses before a code is dead
const RESET_REQUESTS_PER_PHONE_PER_HOUR = 3;
const RESET_REQUESTS_PER_IP_PER_HOUR = 10;
const HOUR_MS = 60 * 60 * 1000;
const RESET_GENERIC_ERROR = 'Invalid or expired code';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly throttle = new LoginThrottle();
  private readonly resetThrottle = new LoginThrottle(); // failed reset-code submissions (phone + ip)
  private readonly passwordThrottle = new LoginThrottle(); // wrong current-password guesses (by user)
  private readonly resetRequests = new Map<string, number[]>(); // 'phone:+88..' / 'ip:..' -> request times

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly sms: SmsService,
  ) { }

  async register(
    dto: RegisterDto,
  ): Promise<{ user: SafeUser; tokens: TokenPair }> {
    await assertValidDetails(this.prisma, dto);
    const passwordHash = await argon2.hash(dto.password);

    let user: User;
    try {
      user = await this.prisma.user.create({
        data: {
          phone: dto.phone,
          name: dto.name,
          address: dto.address,
          passwordHash,
          languagePreference: dto.languagePreference,
          dateOfBirth: dateOfBirthColumn(dto.dateOfBirth),
          genderId: dto.genderId,
          divisionId: dto.divisionId,
          districtId: dto.districtId,
          upazilaId: dto.upazilaId,
        },
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        throw new ConflictException('Phone number is already registered');
      }
      throw err;
    }

    const tokens = await this.issueTokens(user);
    return { user: sanitizeUser(user), tokens };
  }

  async login(dto: LoginDto, clientIp = 'unknown'): Promise<{ user: SafeUser; tokens: TokenPair }> {
    const throttleKey = `${clientIp}|${dto.phone}`;
    if (this.throttle.isBlocked(throttleKey)) {
      throw new HttpException(
        'Too many failed login attempts. Please try again in a few minutes.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    // Same error and same work for "no such user" and "wrong password" so
    // neither the message nor the response time reveals which phone numbers
    // are registered.
    const passwordMatches = await argon2.verify(
      user ? user.passwordHash : await DUMMY_HASH_PROMISE,
      dto.password,
    );
    if (!user || !passwordMatches) {
      this.throttle.recordFailure(throttleKey);
      throw new UnauthorizedException('Invalid phone number or password');
    }

    if (user.accountStatus !== 'ACTIVE') {
      throw new ForbiddenException('Account is not active');
    }

    this.throttle.reset(throttleKey);
    const tokens = await this.issueTokens(user);
    return { user: sanitizeUser(user), tokens };
  }

  /**
   * Stateless JWT: nothing is stored server-side, so there is nothing to
   * revoke. The client simply discards its token. (Suspended accounts are
   * still cut off immediately - JwtAccessStrategy re-checks the user on
   * every request.)
   */
  async logout(_userId: string): Promise<void> {
    return;
  }

  async changePassword(
    userId: string,
    dto: ChangePasswordDto,
  ): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException();
    }

    // A stolen session must not be able to brute-force the current password.
    if (this.passwordThrottle.isBlocked(userId)) {
      throw new HttpException('Too many attempts. Please try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    const currentMatches = await argon2.verify(
      user.passwordHash,
      dto.currentPassword,
    );
    if (!currentMatches) {
      this.passwordThrottle.recordFailure(userId);
      // 403, not 401: the app treats any 401 as "session expired" and logs the user out.
      throw new ForbiddenException('Current password is incorrect');
    }
    this.passwordThrottle.reset(userId);

    const newPasswordHash = await argon2.hash(dto.newPassword);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newPasswordHash },
    });
  }

  /**
   * Step 1 of "forgot password". ALWAYS answers the same way, whether or not
   * the number has an account (no account enumeration), and does the work in
   * the background so the response time is the same too. A code is only
   * texted to the phone that owns the account: knowing a phone number is not
   * enough to reset its password.
   */
  async forgotPassword(dto: ForgotPasswordDto, clientIp = 'unknown'): Promise<{ message: string }> {
    if (this.exceedsRequestLimit(`ip:${clientIp}`, RESET_REQUESTS_PER_IP_PER_HOUR)) {
      throw new HttpException('Too many requests. Please try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    void this.issueResetCode(dto.phone).catch(() => this.logger.error('Reset code could not be issued'));
    return { message: 'If an account exists for this number, a verification code has been sent.' };
  }

  private async issueResetCode(phone: string): Promise<void> {
    if (this.exceedsRequestLimit(`phone:${phone}`, RESET_REQUESTS_PER_PHONE_PER_HOUR)) return;
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user || user.accountStatus !== 'ACTIVE') return;

    const code = String(randomInt(100000, 1000000));
    const data = { codeHash: this.hashResetCode(user.id, code), attempts: 0, expiresAt: new Date(Date.now() + RESET_CODE_TTL_MS) };
    // One live code per user: a new request replaces the old one.
    await this.prisma.passwordResetCode.upsert({ where: { userId: user.id }, create: { userId: user.id, ...data }, update: data });
    await this.sms.send(phone, `Medi-Bela: your password reset code is ${code}. It expires in 10 minutes. Never share it.`);
  }

  /**
   * Step 2: phone + SMS code + new password. Every failure (unknown phone,
   * wrong/expired/used code) returns the same error. Codes are single-use,
   * expire after 10 minutes and die after 5 wrong guesses. On success all
   * earlier sessions (access tokens) stop working.
   */
  async resetPassword(dto: ResetPasswordDto, clientIp = 'unknown'): Promise<void> {
    const throttleKey = `${clientIp}|${dto.phone}`;
    if (this.resetThrottle.isBlocked(throttleKey)) {
      throw new HttpException('Too many attempts. Please try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    const fail = (): never => {
      this.resetThrottle.recordFailure(throttleKey);
      throw new BadRequestException(RESET_GENERIC_ERROR);
    };

    const user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
    const row = user ? await this.prisma.passwordResetCode.findUnique({ where: { userId: user.id } }) : null;
    if (!user || !row || user.accountStatus !== 'ACTIVE') return fail();
    if (row.expiresAt.getTime() < Date.now() || row.attempts >= RESET_MAX_CODE_ATTEMPTS) return fail();

    const expected = Buffer.from(row.codeHash, 'hex');
    const given = Buffer.from(this.hashResetCode(user.id, dto.code), 'hex');
    if (expected.length !== given.length || !timingSafeEqual(expected, given)) {
      await this.prisma.passwordResetCode.update({ where: { id: row.id }, data: { attempts: { increment: 1 } } });
      return fail();
    }

    const passwordHash = await argon2.hash(dto.newPassword);
    await this.prisma.$transaction(async (tx) => {
      // Consume the code exactly once, even if the same code is submitted twice at once.
      const consumed = await tx.passwordResetCode.deleteMany({ where: { id: row.id } });
      if (consumed.count !== 1) throw new BadRequestException(RESET_GENERIC_ERROR);
      await tx.user.update({ where: { id: user.id }, data: { passwordHash, passwordChangedAt: new Date() } });
    });
    this.resetThrottle.reset(throttleKey);
    this.throttle.reset(throttleKey);
  }

  /** HMAC (server secret) of the code, so a database leak does not reveal live codes. */
  private hashResetCode(userId: string, code: string): string {
    return createHmac('sha256', this.config.getOrThrow<string>('JWT_ACCESS_SECRET')).update(`${userId}:${code}`).digest('hex');
  }

  /** Counts one request for `key`; true once it exceeds `max` within the last hour. */
  private exceedsRequestLimit(key: string, max: number, now = Date.now()): boolean {
    const hits = (this.resetRequests.get(key) ?? []).filter((t) => now - t < HOUR_MS);
    hits.push(now);
    this.resetRequests.set(key, hits);
    if (this.resetRequests.size > 10_000) {
      for (const [k, v] of this.resetRequests) if (v.every((t) => now - t >= HOUR_MS)) this.resetRequests.delete(k);
    }
    return hits.length > max;
  }

  private async issueTokens(user: User): Promise<TokenPair> {
    const payload: JwtPayload = {
      sub: user.id,
      phone: user.phone,
      role: user.role,
    };

    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      // Single long-lived token (MVP: no refresh flow).
      expiresIn: this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '30d') as any,
    });

    return { accessToken };
  }
}
