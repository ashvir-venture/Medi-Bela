import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { MedicineScheduleService } from './medicine-schedule.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { MarkDoseTakenDto } from './dto/mark-dose-taken.dto';

@Controller('medicine-schedule')
export class MedicineScheduleController {
  constructor(private readonly schedule: MedicineScheduleService) {}

  @Get('routines')
  getActiveRoutines(@CurrentUser('id') userId: string) {
    return this.schedule.getActiveRoutines(userId);
  }

  @Get('routines/:id')
  getRoutine(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.schedule.getRoutineDetail(userId, id);
  }

  @Get('today')
  getToday(@CurrentUser('id') userId: string) {
    return this.schedule.getTodaysSchedule(userId);
  }

  @Get('upcoming')
  getUpcoming(@CurrentUser('id') userId: string, @Query('days') days?: string) {
    const parsedDays = days ? Number(days) : 7;
    if (!Number.isInteger(parsedDays) || parsedDays < 1 || parsedDays > 30) {
      throw new BadRequestException('days must be an integer between 1 and 30');
    }
    return this.schedule.getUpcomingDoses(userId, parsedDays);
  }

  /**
   * Incremental sync endpoint: `since` is an ISO timestamp the mobile app
   * persists from the previous call's `syncedAt`. Returns only routines
   * (with their doses) that changed after that point.
   */
  @Get('changes')
  getChanges(@CurrentUser('id') userId: string, @Query('since') since?: string) {
    const sinceDate = since ? new Date(since) : new Date(0);
    if (Number.isNaN(sinceDate.getTime())) {
      throw new BadRequestException('since must be a valid ISO timestamp');
    }
    return this.schedule.getChangesSince(userId, sinceDate);
  }

  /**
   * Dose history, most recent first. `from`/`to` default to a 30-day
   * trailing window if omitted so the response stays bounded.
   * NOTE: declared before `doses/:id` so "history" is never captured as
   * the `:id` param.
   */
  @Get('doses/history')
  getDoseHistory(
    @CurrentUser('id') userId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const toDate = to ? new Date(to) : new Date();
    const fromDate = from ? new Date(from) : new Date(toDate.getTime() - 30 * 24 * 60 * 60 * 1000);
    if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
      throw new BadRequestException('from/to must be valid ISO timestamps');
    }
    return this.schedule.getDoseHistory(userId, fromDate, toDate);
  }

  @Get('doses/:id')
  getDose(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.schedule.getDoseDetail(userId, id);
  }

  @Post('doses/:id/taken')
  markDoseTaken(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: MarkDoseTakenDto,
  ) {
    return this.schedule.markDoseTaken(userId, id, dto.takenAt);
  }
}
