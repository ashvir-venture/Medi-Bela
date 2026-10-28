import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { Role } from '@prisma/client';
import { NoticesService } from './notices.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { CreateNoticeDto } from './dto/create-notice.dto';
import { UpdateNoticeDto } from './dto/update-notice.dto';

@Controller()
export class NoticesController {
  constructor(private readonly notices: NoticesService) {}

  // --- User-facing: only published, non-expired, audience-matched -----

  @Get('notices/mine')
  listMine(@CurrentUser('role') role: Role) {
    return this.notices.listVisibleTo(role);
  }

  // --- Admin -----------------------------------------------------------

  @Get('admin/notices')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  list() {
    return this.notices.listForAdmin();
  }

  @Get('admin/notices/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  getDetail(@Param('id', ParseUUIDPipe) id: string) {
    return this.notices.getDetail(id);
  }

  @Post('admin/notices')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  create(@CurrentUser('id') adminId: string, @Body() dto: CreateNoticeDto) {
    return this.notices.create(adminId, dto);
  }

  @Patch('admin/notices/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateNoticeDto) {
    return this.notices.update(id, dto);
  }

  // Admin only: pharmacists can draft notices but not send them to users.
  @Post('admin/notices/:id/publish')
  @Roles(Role.ADMIN)
  publish(@Param('id', ParseUUIDPipe) id: string) {
    return this.notices.publish(id);
  }

  @Post('admin/notices/:id/archive')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  archive(@Param('id', ParseUUIDPipe) id: string) {
    return this.notices.archive(id);
  }

  @Delete('admin/notices/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.notices.remove(id);
  }
}
