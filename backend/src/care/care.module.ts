import { Module } from '@nestjs/common';
import { FamilyModule } from '../family/family.module';
import { CareController } from './care.controller';
import { CareService } from './care.service';

/** Round 15: conditions, limits, care settings, ticks, logs, questions. */
@Module({
  imports: [FamilyModule],
  controllers: [CareController],
  providers: [CareService],
})
export class CareModule {}
