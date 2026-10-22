import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { AccountStatus, NotificationType, Prisma, PushStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { DeviceTokensService } from './device-tokens.service';
import { PushService } from './push.service';

export const MAX_PUSH_ATTEMPTS = 3;
/** Push older than this is stale (e.g. "missed dose" from yesterday) — don't deliver late. */
const MAX_PUSH_AGE_MS = 6 * 60 * 60 * 1000;
const SEND_CONCURRENCY = 20;

export interface NewNotification {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  /** With (userId, type) forms the idempotency key — pass the event's own id. */
  relatedEntityId: string;
  data?: Record<string, string>;
}

type Db = PrismaService | Prisma.TransactionClient;

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
    private readonly devices: DeviceTokensService,
  ) {}

  // ---------------------------------------------------------------------
  // Creation
  // ---------------------------------------------------------------------

  /**
   * Inserts notification rows, silently skipping any (userId, type,
   * relatedEntityId) that already exists — the DB unique constraint is the
   * duplicate guard, so concurrent producers or a retried job cannot create
   * a second notification for the same event. Returns ids of NEWLY created rows
   * only, so callers dispatch push exactly for those.
   *
   * Pass `tx` to create rows atomically with the state change that caused them.
   */
  async createMany(items: NewNotification[], tx?: Prisma.TransactionClient): Promise<string[]> {
    if (items.length === 0) return [];
    const db: Db = tx ?? this.prisma;
    const ids: string[] = [];
    for (let i = 0; i < items.length; i += 1000) {
      const chunk = items.slice(i, i + 1000);
      const created = await db.notification.createManyAndReturn({
        data: chunk.map((n) => ({
          userId: n.userId,
          type: n.type,
          title: n.title,
          body: n.body,
          relatedEntityId: n.relatedEntityId,
          data: n.data ?? Prisma.JsonNull,
        })),
        skipDuplicates: true,
        select: { id: true },
      });
      ids.push(...created.map((c) => c.id));
    }
    return ids;
  }

  /** Create + best-effort immediate push. Never throws: a notification must not break the business action that caused it. */
  async notify(items: NewNotification[]): Promise<void> {
    try {
      const ids = await this.createMany(items);
      await this.dispatch(ids);
    } catch (err) {
      this.logger.error(`notify failed: ${(err as Error).message}`);
    }
  }

  // ---------------------------------------------------------------------
  // Push dispatch (at-most-MAX_PUSH_ATTEMPTS, never twice once SENT)
  // ---------------------------------------------------------------------

  async dispatch(ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    const rows = await this.prisma.notification.findMany({
      where: { id: { in: ids }, pushStatus: PushStatus.PENDING },
    });
    await this.process(rows);
  }

  /** Retry sweep for anything still PENDING (first attempt failed, or created while the process was down). */
  async dispatchPending(limit = 200): Promise<number> {
    const rows = await this.prisma.notification.findMany({
      where: {
        pushStatus: PushStatus.PENDING,
        pushAttempts: { lt: MAX_PUSH_ATTEMPTS },
        createdAt: { gt: new Date(Date.now() - MAX_PUSH_AGE_MS) },
      },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
    await this.process(rows);

    // Anything that aged out or exhausted its attempts without being sent is closed, not retried forever.
    await this.prisma.notification.updateMany({
      where: {
        pushStatus: PushStatus.PENDING,
        OR: [
          { pushAttempts: { gte: MAX_PUSH_ATTEMPTS } },
          { createdAt: { lte: new Date(Date.now() - MAX_PUSH_AGE_MS) } },
        ],
      },
      data: { pushStatus: PushStatus.FAILED },
    });
    return rows.length;
  }

  private async process(candidates: Array<Prisma.NotificationGetPayload<object>>): Promise<void> {
    if (candidates.length === 0) return;

    // 1. Claim. The compare-and-set on pushAttempts means that if two workers
    //    race on the same row, exactly one wins and the other skips it.
    const claimed: typeof candidates = [];
    for (const row of candidates) {
      const claim = await this.prisma.notification.updateMany({
        where: { id: row.id, pushStatus: PushStatus.PENDING, pushAttempts: row.pushAttempts },
        data: { pushAttempts: { increment: 1 } },
      });
      if (claim.count === 1) claimed.push({ ...row, pushAttempts: row.pushAttempts + 1 });
    }
    if (claimed.length === 0) return;

    // 2. Push disabled globally => nothing can ever be sent; close the rows.
    if (!this.push.isEnabled()) {
      await this.setStatus(claimed.map((c) => c.id), PushStatus.SKIPPED);
      return;
    }

    // 3. Recipients who turned notifications off, or whose account is inactive.
    const userIds = [...new Set(claimed.map((c) => c.userId))];
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, notificationsEnabled: true, accountStatus: true },
    });
    const allowed = new Set(
      users
        .filter((u) => u.notificationsEnabled && u.accountStatus === AccountStatus.ACTIVE)
        .map((u) => u.id),
    );
    const blocked = claimed.filter((c) => !allowed.has(c.userId));
    await this.setStatus(blocked.map((c) => c.id), PushStatus.SKIPPED);
    const sendable = claimed.filter((c) => allowed.has(c.userId));

    // 4. Send, with bounded concurrency.
    const tokensByUser = await this.devices.tokensForUsers([...new Set(sendable.map((c) => c.userId))]);
    for (let i = 0; i < sendable.length; i += SEND_CONCURRENCY) {
      await Promise.all(
        sendable.slice(i, i + SEND_CONCURRENCY).map((n) => this.sendOne(n, tokensByUser.get(n.userId) ?? [])),
      );
    }
  }

  private async sendOne(
    n: Prisma.NotificationGetPayload<object>,
    tokens: Array<{ id: string; token: string }>,
  ) {
    if (tokens.length === 0) {
      await this.setStatus([n.id], PushStatus.SKIPPED); // no registered device
      return;
    }
    try {
      const results = await this.push.send(
        tokens.map((t) => t.token),
        {
          title: n.title,
          body: n.body,
          collapseKey: n.id,
          data: {
            ...((n.data as Record<string, string> | null) ?? {}),
            notificationId: n.id,
            type: n.type,
          },
        },
      );

      const dead = results.filter((r) => r.permanentTokenFailure).map((r) => r.token);
      if (dead.length > 0) {
        await this.devices.removeByIds(tokens.filter((t) => dead.includes(t.token)).map((t) => t.id));
      }

      if (results.some((r) => r.ok)) {
        await this.prisma.notification.update({
          where: { id: n.id },
          data: { pushStatus: PushStatus.SENT, pushedAt: new Date() },
        });
      } else if (results.every((r) => r.permanentTokenFailure)) {
        await this.setStatus([n.id], PushStatus.SKIPPED); // every device was gone
      } else if (n.pushAttempts >= MAX_PUSH_ATTEMPTS) {
        await this.setStatus([n.id], PushStatus.FAILED);
      } // else: stays PENDING, retried by dispatchPending()
    } catch (err) {
      // Never log tokens or message bodies.
      this.logger.warn(`Push send failed for notification ${n.id}: ${(err as Error).message}`);
      if (n.pushAttempts >= MAX_PUSH_ATTEMPTS) await this.setStatus([n.id], PushStatus.FAILED);
    }
  }

  private async setStatus(ids: string[], status: PushStatus) {
    if (ids.length === 0) return;
    await this.prisma.notification.updateMany({ where: { id: { in: ids } }, data: { pushStatus: status } });
  }

  // ---------------------------------------------------------------------
  // In-app inbox (always scoped to the caller)
  // ---------------------------------------------------------------------

  async list(userId: string, limit = 30, before?: string) {
    const rows = await this.prisma.notification.findMany({
      where: { userId, ...(before ? { createdAt: { lt: new Date(before) } } : {}) },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      select: {
        id: true,
        type: true,
        title: true,
        body: true,
        data: true,
        isRead: true,
        readAt: true,
        createdAt: true,
      },
    });
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const unreadCount = await this.prisma.notification.count({ where: { userId, isRead: false } });
    return {
      items,
      unreadCount,
      nextCursor: hasMore ? items[items.length - 1].createdAt.toISOString() : null,
    };
  }

  async markRead(userId: string, id: string): Promise<void> {
    const res = await this.prisma.notification.updateMany({
      where: { id, userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    if (res.count === 0) {
      // Either someone else's/nonexistent (404) or already read (fine).
      const exists = await this.prisma.notification.findFirst({ where: { id, userId }, select: { id: true } });
      if (!exists) throw new NotFoundException('Notification not found');
    }
  }

  async markAllRead(userId: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }
}
