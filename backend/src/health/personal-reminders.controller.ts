import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';
import { PersonalRemindersService } from './personal-reminders.service';
import {
  CreatePersonalReminderDto,
  PersonalReminderLaterDto,
  UpdatePersonalReminderDto,
} from './dto/personal-reminder.dto';

/**
 * `?forUserId=` = the family caregiver acting for that member. Later is the
 * member's own action (it tells the caregiver), so it takes no forUserId.
 */
@Controller('personal-reminders')
export class PersonalRemindersController {
  constructor(
    private readonly reminders: PersonalRemindersService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  @Get()
  async list(
    @CurrentUser('id') userId: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    const acting = await this.caregivers.resolve(userId, forUserId);
    return this.reminders.list(acting.subjectId);
  }

  @Post()
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePersonalReminderDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.reminders.create(await this.caregivers.resolve(userId, forUserId), dto);
  }

  @Patch(':id')
  async update(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePersonalReminderDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.reminders.update(await this.caregivers.resolve(userId, forUserId), id, dto);
  }

  @Delete(':id')
  async remove(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.reminders.remove(await this.caregivers.resolve(userId, forUserId), id);
  }

  @Post(':id/later')
  later(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PersonalReminderLaterDto,
  ) {
    return this.reminders.later(userId, id, dto.at);
  }
}
