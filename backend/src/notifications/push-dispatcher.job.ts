import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationsService } from './notifications.service';

/** Retries pushes that are still PENDING and drains large fan-outs (e.g. a published notice). */
@Injectable()
export class PushDispatcherJob {
  private readonly logger = new Logger(PushDispatcherJob.name);
  private running = false;

  constructor(private readonly notifications: NotificationsService) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async tick() {
    if (this.running || process.env.PUSH_DISPATCH_JOB_ENABLED === 'false') return;
    this.running = true;
    const deadline = Date.now() + 50_000; // stay inside the minute
    try {
      let processed: number;
      do {
        processed = await this.notifications.dispatchPending(200);
      } while (processed === 200 && Date.now() < deadline);
    } catch (err) {
      this.logger.error(`Push dispatch tick failed: ${(err as Error).message}`);
    } finally {
      this.running = false;
    }
  }
}
