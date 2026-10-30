import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { FamilyService } from './family.service';
import { CreateFamilyDto } from './dto/create-family.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('family')
export class FamilyController {
  constructor(private readonly familyService: FamilyService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser('id') userId: string, @Body() dto: CreateFamilyDto) {
    return this.familyService.createFamily(userId, dto);
  }

  @Get()
  getMine(@CurrentUser('id') userId: string) {
    return this.familyService.getMyFamily(userId);
  }

  @Get('members')
  listMembers(@CurrentUser('id') userId: string) {
    return this.familyService.listMembers(userId);
  }

  /** Today's dose counts per other family member. Declared before `members/:userId/status`. */
  @Get('members/status')
  membersStatus(@CurrentUser('id') userId: string) {
    return this.familyService.getMembersStatusSummary(userId);
  }

  /** Caregiver only; not themself (they use leave). */
  @Delete('members/:userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeMember(
    @CurrentUser('id') userId: string,
    @Param('userId', ParseUUIDPipe) memberUserId: string,
  ) {
    await this.familyService.removeMember(userId, memberUserId);
  }

  @Post('leave')
  @HttpCode(HttpStatus.NO_CONTENT)
  async leave(@CurrentUser('id') userId: string) {
    await this.familyService.leave(userId);
  }

  /** Activity feed of my family, newest first, 10 per page. */
  @Get('events')
  events(@CurrentUser('id') userId: string, @Query('cursor') cursor?: string) {
    return this.familyService.listEvents(userId, cursor);
  }

  @Get('members/:userId/status')
  memberStatus(
    @CurrentUser('id') userId: string,
    @Param('userId', ParseUUIDPipe) memberUserId: string,
  ) {
    return this.familyService.getMemberStatus(userId, memberUserId);
  }

  @Post('invitations')
  @HttpCode(HttpStatus.CREATED)
  invite(@CurrentUser('id') userId: string, @Body() dto: InviteMemberDto) {
    return this.familyService.inviteMember(userId, dto);
  }

  /**
   * `type=incoming` (default): pending invitations addressed to me.
   * `type=sent`: pending invitations sent by my family (caregiver only).
   */
  @Get('invitations')
  listInvitations(
    @CurrentUser('id') userId: string,
    @CurrentUser('phone') phone: string,
    @Query('type') type: string = 'incoming',
  ) {
    return type === 'sent'
      ? this.familyService.listSentInvitations(userId)
      : this.familyService.listIncomingInvitations(phone);
  }

  @Post('invitations/:id/accept')
  accept(
    @CurrentUser('id') userId: string,
    @CurrentUser('phone') phone: string,
    @Param('id', ParseUUIDPipe) invitationId: string,
  ) {
    return this.familyService.acceptInvitation(userId, phone, invitationId);
  }

  @Post('invitations/:id/decline')
  decline(
    @CurrentUser('phone') phone: string,
    @Param('id', ParseUUIDPipe) invitationId: string,
  ) {
    return this.familyService.declineInvitation(phone, invitationId);
  }
}
