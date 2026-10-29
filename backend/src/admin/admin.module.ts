import { Module } from '@nestjs/common';
import { AdminAnalyticsController } from './admin-analytics.controller';
import { AdminAnalyticsService } from './admin-analytics.service';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminDashboardService } from './admin-dashboard.service';
import { PharmacistDashboardController } from './pharmacist-dashboard.controller';
import { PharmacistDashboardService } from './pharmacist-dashboard.service';

@Module({
  controllers: [AdminDashboardController, AdminAnalyticsController, PharmacistDashboardController],
  providers: [AdminDashboardService, AdminAnalyticsService, PharmacistDashboardService],
})
export class AdminModule {}
