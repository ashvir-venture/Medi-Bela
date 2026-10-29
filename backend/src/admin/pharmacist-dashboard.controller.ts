import { Controller, Get } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PharmacistDashboardService } from './pharmacist-dashboard.service';

@Controller('pharmacist/dashboard')
@Roles(Role.PHARMACIST)
export class PharmacistDashboardController {
  constructor(private readonly dashboard: PharmacistDashboardService) {}

  @Get()
  get(@CurrentUser('id') pharmacistId: string) {
    return this.dashboard.getDashboard(pharmacistId);
  }
}
