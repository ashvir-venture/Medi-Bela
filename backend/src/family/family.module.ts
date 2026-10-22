import { Module } from '@nestjs/common';
import { FamilyController } from './family.controller';
import { FamilyService } from './family.service';

// PrismaModule and NotificationsModule are @Global().
@Module({
  controllers: [FamilyController],
  providers: [FamilyService],
})
export class FamilyModule {}
