import { Module } from '@nestjs/common';
import { FamilyController } from './family.controller';
import { FamilyService } from './family.service';
import { CaregiverAccessService } from './caregiver-access.service';

// PrismaModule and NotificationsModule are @Global().
@Module({
  controllers: [FamilyController],
  providers: [FamilyService, CaregiverAccessService],
  exports: [CaregiverAccessService],
})
export class FamilyModule {}
