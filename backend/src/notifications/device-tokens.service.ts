import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TokenCryptoService } from './token-crypto.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

/** A user rarely has more than a phone + tablet; cap so a client bug can't grow this unbounded. */
const MAX_TOKENS_PER_USER = 5;

export interface UserDeviceToken {
  id: string;
  userId: string;
  token: string;
}

@Injectable()
export class DeviceTokensService {
  private readonly logger = new Logger(DeviceTokensService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: TokenCryptoService,
  ) {}

  /**
   * Register or refresh. Idempotent — the app may call it on every launch.
   *
   * The token is keyed by its hash and OWNERSHIP FOLLOWS THE LATEST AUTHENTICATED
   * REGISTRATION: if user B logs in on a phone user A used, the same install's token
   * moves to B, so A never receives B's alerts on that handset. The token string only
   * ever reaches a device, so reassigning cannot leak anything to the caller.
   */
  async register(userId: string, dto: RegisterDeviceDto): Promise<void> {
    const tokenHash = this.crypto.hash(dto.token);
    const tokenEnc = this.crypto.encrypt(dto.token);
    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      if (dto.previousToken && dto.previousToken !== dto.token) {
        // Scoped to the caller: you can only retire your own tokens.
        await tx.deviceToken.deleteMany({
          where: { userId, tokenHash: this.crypto.hash(dto.previousToken) },
        });
      }

      await tx.deviceToken.upsert({
        where: { tokenHash },
        create: {
          userId,
          tokenHash,
          tokenEnc,
          platform: dto.platform,
          appVersion: dto.appVersion ?? null,
          lastSeenAt: now,
        },
        update: {
          userId,
          tokenEnc,
          platform: dto.platform,
          appVersion: dto.appVersion ?? null,
          lastSeenAt: now,
        },
      });

      const mine = await tx.deviceToken.findMany({
        where: { userId },
        orderBy: { lastSeenAt: 'desc' },
        select: { id: true },
      });
      if (mine.length > MAX_TOKENS_PER_USER) {
        await tx.deviceToken.deleteMany({
          where: { id: { in: mine.slice(MAX_TOKENS_PER_USER).map((t) => t.id) } },
        });
      }
    });
  }

  /** Logout / push disabled. Idempotent; only removes the caller's own token. */
  async unregister(userId: string, token: string): Promise<void> {
    await this.prisma.deviceToken.deleteMany({
      where: { userId, tokenHash: this.crypto.hash(token) },
    });
  }

  async tokensForUsers(userIds: string[]): Promise<Map<string, UserDeviceToken[]>> {
    const result = new Map<string, UserDeviceToken[]>();
    if (userIds.length === 0) return result;

    const rows = await this.prisma.deviceToken.findMany({
      where: { userId: { in: userIds } },
      select: { id: true, userId: true, tokenEnc: true },
    });
    for (const row of rows) {
      try {
        const entry = { id: row.id, userId: row.userId, token: this.crypto.decrypt(row.tokenEnc) };
        const list = result.get(row.userId) ?? [];
        list.push(entry);
        result.set(row.userId, list);
      } catch {
        // Undecryptable (e.g. key rotated): useless row, drop it. Never log the payload.
        this.logger.warn(`Dropping undecryptable device token ${row.id}`);
        await this.prisma.deviceToken.delete({ where: { id: row.id } }).catch(() => undefined);
      }
    }
    return result;
  }

  /** Called after FCM reports a token as permanently invalid/unregistered. */
  async removeByIds(ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    await this.prisma.deviceToken.deleteMany({ where: { id: { in: ids } } });
  }
}
