import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { HealthRemindersService } from './health-reminders.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CompleteHealthReminderDto } from './dto/complete-health-reminder.dto';

@Controller('health-reminders')
export class HealthRemindersController {
  constructor(private readonly reminders: HealthRemindersService) {}

  @Get()
  list(@CurrentUser('id') userId: string) {
    return this.reminders.list(userId);
  }

  @Get('upcoming')
  getUpcoming(@CurrentUser('id') userId: string) {
    return this.reminders.getUpcoming(userId);
  }

  @Get('due')
  getDue(@CurrentUser('id') userId: string) {
    return this.reminders.getDue(userId);
  }

  @Get(':id')
  getDetail(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.reminders.getDetail(userId, id);
  }

  @Post(':id/complete')
  markComplete(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CompleteHealthReminderDto,
  ) {
    return this.reminders.markComplete(userId, id, dto.completedAt);
  }
}
