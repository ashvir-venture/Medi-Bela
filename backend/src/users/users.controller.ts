import { Body, Controller, Delete, Get, HttpCode, HttpStatus, ParseUUIDPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { UpdateReminderTimingDto } from './dto/update-reminder-timing.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';

@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  /**
   * Deliberately `/users/me` rather than `/users/:id` — there is no
   * route that takes an arbitrary user id, so there is nothing for a
   * caller to tamper with to reach another user's profile (IDOR-safe
   * by construction).
   */
  @Get('me')
  getMe(@CurrentUser('id') userId: string) {
    return this.usersService.getById(userId);
  }

  @Patch('me')
  updateMe(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.usersService.updateProfile(userId, dto);
  }

  /**
   * Round 14: reminder timings in effect, the .env defaults and the user's own values.
   * Round 18: `?forUserId=` = the caregiver for a member (needs the member's View permission).
   */
  @Get('me/reminder-timing')
  async getReminderTiming(@CurrentUser('id') userId: string, @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string) {
    const acting = await this.caregivers.resolve(userId, forUserId, 'view');
    return this.usersService.getReminderTiming(acting.subjectId);
  }

  /**
   * Round 14: the user's own ring gap, Later delay, rings and family-alert time (null = default).
   * Round 18 (client point 14): the caregiver may set them for a member with the member's Manage
   * permission (audited, the member is told).
   */
  @Put('me/reminder-timing')
  async updateReminderTiming(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateReminderTimingDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    const acting = await this.caregivers.resolve(userId, forUserId, 'manage');
    const result = await this.usersService.updateReminderTiming(acting.subjectId, dto, acting);
    await this.caregivers.notifyMember(acting, 'reminder_timing_updated', `${Date.now()}`);
    return result;
  }

  /** Pause the signed-in user's own account until they sign in again (re-authenticated with the password). */
  @Post('me/deactivate')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deactivateMe(@CurrentUser('id') userId: string, @Body() dto: DeleteAccountDto) {
    await this.usersService.deactivate(userId, dto.password);
  }

  /** Delete the signed-in user's own account (re-authenticated with the password). */
  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteMe(@CurrentUser('id') userId: string, @Body() dto: DeleteAccountDto) {
    await this.usersService.deleteAccount(userId, dto.password);
  }
}
