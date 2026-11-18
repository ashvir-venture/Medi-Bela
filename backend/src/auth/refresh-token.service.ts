import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RefreshClient } from '@prisma/client';
import { createHash, randomBytes, randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { ErrorCode, withCode } from '../common/filters/error-codes';

/** A presented token that was already used is accepted again for this long
 * (two refreshes racing: the app's foreground and its reminder isolate). */
export const REUSE_GRACE_MS = 60_000;

export interface IssuedRefresh {
  token: string;
  familyId: string;
  expiresAt: Date;
}

export interface RotatedRefresh extends IssuedRefresh {
  userId: string;
  client: RefreshClient;
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Round 18 refresh tokens (owner 2026-11-17): app 60 days, panel 7 days,
 * rotation on every refresh, a used token presented again (after the grace
 * window) signs that whole family out. Only hashes are stored.
 */
@Injectable()
export class RefreshTokenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  ttlDays(client: RefreshClient): number {
    const key = client === RefreshClient.PANEL ? 'REFRESH_TTL_DAYS_PANEL' : 'REFRESH_TTL_DAYS_APP';
    const fallback = client === RefreshClient.PANEL ? 7 : 60;
    const n = Number(this.config.get<string>(key));
    return Number.isFinite(n) && n > 0 ? n : fallback;
  }

  /** A new family (a sign-in) or the next token of an existing one. */
  async issue(userId: string, client: RefreshClient, familyId: string = randomUUID(), now = new Date()): Promise<IssuedRefresh> {
    const token = randomBytes(48).toString('base64url');
    const expiresAt = new Date(now.getTime() + this.ttlDays(client) * 86_400_000);
    await this.prisma.refreshToken.create({
      data: { userId, familyId, client, tokenHash: hashRefreshToken(token), expiresAt, createdAt: now },
    });
    return { token, familyId, expiresAt };
  }

  /**
   * Trades a refresh token for the next one. Refuses (401 SESSION_EXPIRED)
   * an unknown, expired or revoked token, one from before the user's last
   * password reset or pause, and an account that isn't ACTIVE. A used token
   * presented again after [REUSE_GRACE_MS] revokes its family.
   */
  async rotate(token: string, now = new Date()): Promise<RotatedRefresh> {
    const expired = () => withCode(new UnauthorizedException('Session expired. Please log in again.'), ErrorCode.SESSION_EXPIRED);
    if (!token) throw expired();
    const row = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: hashRefreshToken(token) },
      include: { user: { select: { accountStatus: true, passwordChangedAt: true } } },
    });
    if (!row || row.revokedAt || row.expiresAt <= now) throw expired();
    if (row.user.accountStatus !== 'ACTIVE') throw expired();
    if (row.user.passwordChangedAt && row.createdAt < row.user.passwordChangedAt) throw expired();

    if (row.usedAt) {
      if (now.getTime() - row.usedAt.getTime() > REUSE_GRACE_MS) {
        await this.revokeFamily(row.familyId, now);
        throw expired();
      }
    } else {
      // Compare-and-set: of two racing refreshes only one marks it used; the
      // other falls into the grace window above on its next try, or is
      // simply given its own next token here (both inside the grace window).
      await this.prisma.refreshToken.updateMany({ where: { id: row.id, usedAt: null }, data: { usedAt: now } });
    }
    const next = await this.issue(row.userId, row.client, row.familyId, now);
    return { ...next, userId: row.userId, client: row.client };
  }

  /** Sign-out of one device: the family of the presented token. */
  async revokeByToken(token: string | undefined, now = new Date()): Promise<void> {
    if (!token) return;
    const row = await this.prisma.refreshToken.findUnique({ where: { tokenHash: hashRefreshToken(token) }, select: { familyId: true } });
    if (row) await this.revokeFamily(row.familyId, now);
  }

  async revokeFamily(familyId: string, now = new Date()): Promise<void> {
    await this.prisma.refreshToken.updateMany({ where: { familyId, revokedAt: null }, data: { revokedAt: now } });
  }

  /** Every device but [keepFamilyId] (a password change keeps this one). */
  async revokeAllForUser(userId: string, keepFamilyId?: string, now = new Date()): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null, ...(keepFamilyId ? { NOT: { familyId: keepFamilyId } } : {}) },
      data: { revokedAt: now },
    });
  }

  /** Housekeeping: rows past their expiry (kept a day for reuse detection). */
  async deleteExpired(now = new Date()): Promise<number> {
    const { count } = await this.prisma.refreshToken.deleteMany({ where: { expiresAt: { lt: new Date(now.getTime() - 86_400_000) } } });
    return count;
  }
}
