import { Module } from '@nestjs/common';
import { PrescriptionsController } from './prescriptions.controller';
import { PrescriptionsService } from './prescriptions.service';
import { RoutineGenerationService } from './lib/routine-generation.service';
import { CloudinaryService } from './lib/cloudinary.service';
import { HealthModule } from '../health/health.module';

@Module({
  imports: [HealthModule],
  controllers: [PrescriptionsController],
  providers: [PrescriptionsService, RoutineGenerationService, CloudinaryService],
  exports: [RoutineGenerationService],
})
export class PrescriptionsModule {}
