import { Controller, Get } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { AdminDashboardService } from './admin-dashboard.service';

@Controller('admin/dashboard')
// Pharmacists have their own overview at /pharmacist/dashboard.
@Roles(Role.ADMIN)
export class AdminDashboardController {
  constructor(private readonly dashboard: AdminDashboardService) {}

  @Get()
  get() {
    return this.dashboard.getDashboard();
  }
}
