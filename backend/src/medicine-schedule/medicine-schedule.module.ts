import { Module } from '@nestjs/common';
import { MedicineScheduleController } from './medicine-schedule.controller';
import { MedicineScheduleService } from './medicine-schedule.service';
import { MissedDoseAlertService } from './missed-dose-alert.service';
import { RollingDoseJob } from './rolling-dose.job';

@Module({
  controllers: [MedicineScheduleController],
  providers: [MedicineScheduleService, MissedDoseAlertService, RollingDoseJob],
})
export class MedicineScheduleModule {}
