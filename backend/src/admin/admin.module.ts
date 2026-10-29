import { Module } from '@nestjs/common';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminDashboardService } from './admin-dashboard.service';
import { PharmacistDashboardController } from './pharmacist-dashboard.controller';
import { PharmacistDashboardService } from './pharmacist-dashboard.service';

@Module({
  controllers: [AdminDashboardController, PharmacistDashboardController],
  providers: [AdminDashboardService, PharmacistDashboardService],
})
export class AdminModule {}
