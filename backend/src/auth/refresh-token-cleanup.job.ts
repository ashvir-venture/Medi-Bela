import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { RefreshTokenService } from './refresh-token.service';

/** Round 18: once a day, drop refresh-token rows that expired over a day ago. */
@Injectable()
export class RefreshTokenCleanupJob {
  private readonly logger = new Logger(RefreshTokenCleanupJob.name);

  constructor(private readonly refreshTokens: RefreshTokenService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async run(): Promise<void> {
    try {
      const n = await this.refreshTokens.deleteExpired();
      if (n) this.logger.log(`Removed ${n} expired refresh tokens`);
    } catch (e) {
      this.logger.warn(`Refresh token cleanup failed: ${(e as Error).message}`);
    }
  }
}
