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
import { PackPhotoService } from './pack-photo.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';

@Module({
  imports: [FamilyModule, CatalogModule],
  controllers: [MedicineScheduleController, MedicineBoxController],
  providers: [
    MedicineScheduleService,
    MissedDoseAlertService,
    RollingDoseJob,
    RoutineManagementService,
    MedicineBoxService,
    PackPhotoService,
    CloudinaryService,
  ],
})
export class MedicineScheduleModule {}
