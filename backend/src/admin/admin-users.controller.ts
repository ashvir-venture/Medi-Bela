import { Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AdminUsersService } from './admin-users.service';
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';

@Controller('admin/users')
@Roles(Role.ADMIN)
export class AdminUsersController {
  constructor(private readonly users: AdminUsersService) {}

  /** 20 per page, newest first; filters: phone, division, age band, role, status. */
  @Get()
  list(@Query() query: AdminUsersQueryDto) {
    return this.users.list(query);
  }

  @Post(':id/ban')
  ban(@CurrentUser('id') adminId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.users.ban(adminId, id);
  }

  @Post(':id/unban')
  unban(@CurrentUser('id') adminId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.users.unban(adminId, id);
  }
}
