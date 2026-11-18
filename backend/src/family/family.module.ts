import { Module } from '@nestjs/common';
import { FamilyController } from './family.controller';
import { FamilyService } from './family.service';
import { CaregiverAccessService } from './caregiver-access.service';
import { FamilyMembershipService } from './family-membership.service';
import { ChangeHistoryService } from './change-history.service';
import { CaregiverPermissionsService } from './caregiver-permissions.service';

// PrismaModule and NotificationsModule are @Global().
@Module({
  controllers: [FamilyController],
  providers: [FamilyService, CaregiverAccessService, FamilyMembershipService, ChangeHistoryService, CaregiverPermissionsService],
  exports: [CaregiverAccessService, FamilyMembershipService],
})
export class FamilyModule {}
