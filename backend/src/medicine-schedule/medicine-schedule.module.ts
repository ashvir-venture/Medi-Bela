import { Module } from '@nestjs/common';
import { MedicineScheduleController } from './medicine-schedule.controller';
import { MedicineScheduleService } from './medicine-schedule.service';
import { MissedDoseAlertService } from './missed-dose-alert.service';
import { RollingDoseJob } from './rolling-dose.job';
import { RoutineManagementService } from './routine-management.service';
import { MedicineBoxController } from './medicine-box.controller';
import { MedicineBoxService } from './medicine-box.service';
import { FamilyModule } from '../family/family.module';
import { CatalogModule } from '../catalog/catalog.module';

@Module({
  imports: [FamilyModule, CatalogModule],
  controllers: [MedicineScheduleController, MedicineBoxController],
  providers: [
    MedicineScheduleService,
    MissedDoseAlertService,
    RollingDoseJob,
    RoutineManagementService,
    MedicineBoxService,
  ],
})
export class MedicineScheduleModule {}
