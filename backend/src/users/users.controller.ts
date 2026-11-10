import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Patch, Post, Put } from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { UpdateReminderTimingDto } from './dto/update-reminder-timing.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

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

  /** Round 14: reminder timings in effect, the .env defaults and the user's own values. */
  @Get('me/reminder-timing')
  getReminderTiming(@CurrentUser('id') userId: string) {
    return this.usersService.getReminderTiming(userId);
  }

  /** Round 14: the user's own ring gap, Later delay, rings and family-alert time (null = default). */
  @Put('me/reminder-timing')
  updateReminderTiming(@CurrentUser('id') userId: string, @Body() dto: UpdateReminderTimingDto) {
    return this.usersService.updateReminderTiming(userId, dto);
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
