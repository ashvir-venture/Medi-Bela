import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { DeviceTokensService } from './device-tokens.service';
import { NotificationsService } from './notifications.service';
import { RegisterDeviceDto, UnregisterDeviceDto } from './dto/register-device.dto';
import { ListNotificationsDto } from './dto/list-notifications.dto';

/**
 * Every route is authenticated by the global JwtAuthGuard and operates ONLY
 * on the caller's own rows — there is no route that accepts another user's id.
 */
@Controller('notifications')
export class NotificationsController {
  constructor(
    private readonly notifications: NotificationsService,
    private readonly devices: DeviceTokensService,
  ) {}

  @Get()
  list(@CurrentUser('id') userId: string, @Query() query: ListNotificationsDto) {
    return this.notifications.list(userId, query.limit, query.before);
  }

  @Post('read-all')
  @HttpCode(HttpStatus.NO_CONTENT)
  async readAll(@CurrentUser('id') userId: string) {
    await this.notifications.markAllRead(userId);
  }

  /** Register on login / app start, and again whenever FCM rotates the token. */
  @Post('devices')
  @HttpCode(HttpStatus.NO_CONTENT)
  async registerDevice(@CurrentUser('id') userId: string, @Body() dto: RegisterDeviceDto) {
    await this.devices.register(userId, dto);
  }

  /** POST (not DELETE) so the token travels in the body, never in a URL/access log. */
  @Post('devices/unregister')
  @HttpCode(HttpStatus.NO_CONTENT)
  async unregisterDevice(@CurrentUser('id') userId: string, @Body() dto: UnregisterDeviceDto) {
    await this.devices.unregister(userId, dto.token);
  }

  @Post(':id/read')
  @HttpCode(HttpStatus.NO_CONTENT)
  async read(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    await this.notifications.markRead(userId, id);
  }
}
