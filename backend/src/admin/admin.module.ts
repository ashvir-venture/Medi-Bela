import { Module } from '@nestjs/common';
import { AdminAnalyticsController } from './admin-analytics.controller';
import { AdminAnalyticsService } from './admin-analytics.service';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminUsersController } from './admin-users.controller';
import { AdminUsersService } from './admin-users.service';
import { PharmacistDashboardController } from './pharmacist-dashboard.controller';
import { PharmacistDashboardService } from './pharmacist-dashboard.service';

@Module({
  controllers: [AdminDashboardController, AdminAnalyticsController, AdminUsersController, PharmacistDashboardController],
  providers: [AdminDashboardService, AdminAnalyticsService, AdminUsersService, PharmacistDashboardService],
})
export class AdminModule {}
