import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { Role } from '@prisma/client';
import { NoticesService } from './notices.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { CreateNoticeDto } from './dto/create-notice.dto';
import { UpdateNoticeDto } from './dto/update-notice.dto';
import { SendBackNoticeDto } from './dto/send-back-notice.dto';

@Controller()
export class NoticesController {
  constructor(private readonly notices: NoticesService) {}

  // --- User-facing: live, non-expired, audience- and division-matched ----

  @Get('notices/mine')
  listMine(@CurrentUser('id') userId: string, @CurrentUser('role') role: Role) {
    return this.notices.listVisibleTo(userId, role);
  }

  // --- Staff -------------------------------------------------------------
  // Pharmacists draft and submit; admins approve, send back and publish.

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
  create(@CurrentUser('id') actorId: string, @Body() dto: CreateNoticeDto) {
    return this.notices.create(actorId, dto);
  }

  /** Pharmacists: drafts only. Admins: any notice. */
  @Patch('admin/notices/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  update(
    @CurrentUser('id') actorId: string,
    @CurrentUser('role') role: Role,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateNoticeDto,
  ) {
    return this.notices.update(id, { id: actorId, role }, dto);
  }

  @Post('admin/notices/:id/submit')
  @Roles(Role.PHARMACIST)
  submit(@CurrentUser('id') actorId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.notices.submit(id, actorId);
  }

  @Post('admin/notices/:id/withdraw')
  @Roles(Role.PHARMACIST)
  withdraw(@CurrentUser('id') actorId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.notices.withdraw(id, actorId);
  }

  @Post('admin/notices/:id/send-back')
  @Roles(Role.ADMIN)
  sendBack(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SendBackNoticeDto,
  ) {
    return this.notices.sendBack(id, actorId, dto.note);
  }

  /** Publish (admin's own draft), approve (a pharmacist's pending one), or restore an archived one. */
  @Post('admin/notices/:id/publish')
  @Roles(Role.ADMIN)
  publish(@CurrentUser('id') actorId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.notices.publish(id, actorId);
  }

  @Post('admin/notices/:id/archive')
  @Roles(Role.ADMIN)
  archive(@CurrentUser('id') actorId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.notices.archive(id, actorId);
  }

  /** Pharmacists: drafts only. Admins: any notice. */
  @Delete('admin/notices/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  remove(
    @CurrentUser('id') actorId: string,
    @CurrentUser('role') role: Role,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.notices.remove(id, { id: actorId, role });
  }
}
