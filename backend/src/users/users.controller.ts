import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Patch } from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeleteAccountDto } from './dto/delete-account.dto';
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

  /** Delete the signed-in user's own account (re-authenticated with the password). */
  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteMe(@CurrentUser('id') userId: string, @Body() dto: DeleteAccountDto) {
    await this.usersService.deleteAccount(userId, dto.password);
  }
}
