import { Module } from '@nestjs/common';
import { NoticesController } from './notices.controller';
import { NoticesService } from './notices.service';
import { NoticeScheduleJob } from './notice-schedule.job';

@Module({
  controllers: [NoticesController],
  providers: [NoticesService, NoticeScheduleJob],
})
export class NoticesModule {}
