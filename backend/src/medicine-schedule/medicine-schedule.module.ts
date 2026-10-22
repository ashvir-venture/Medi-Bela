import { Module } from '@nestjs/common';
import { MedicineScheduleController } from './medicine-schedule.controller';
import { MedicineScheduleService } from './medicine-schedule.service';
import { MissedDoseAlertService } from './missed-dose-alert.service';

@Module({
  controllers: [MedicineScheduleController],
  providers: [MedicineScheduleService, MissedDoseAlertService],
})
export class MedicineScheduleModule {}
