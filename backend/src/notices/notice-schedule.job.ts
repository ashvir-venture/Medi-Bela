import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NoticesService } from './notices.service';

/**
 * Publishes scheduled notices when their start time comes (and pushes
 * them then). Runs in the API process like the other jobs; single
 * instance only. Toggle with NOTICE_SCHEDULE_JOB_ENABLED.
 */
@Injectable()
export class NoticeScheduleJob {
  private readonly logger = new Logger(NoticeScheduleJob.name);
  private running = false;

  constructor(private readonly notices: NoticesService) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async tick() {
    if (this.running || process.env.NOTICE_SCHEDULE_JOB_ENABLED === 'false') return;
    this.running = true;
    try {
      const live = await this.notices.goLive();
      if (live > 0) this.logger.log(`Scheduled notices published: ${live}`);
    } catch (err) {
      this.logger.error(`Notice schedule tick failed: ${(err as Error).message}`);
    } finally {
      this.running = false;
    }
  }
}
