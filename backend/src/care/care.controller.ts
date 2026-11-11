import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Put, Query } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';
import { CareService } from './care.service';
import {
  CareSettingDto,
  CreateCareLogDto,
  CreateQuestionDto,
  SetConditionsDto,
  SetTickDto,
  UpdateLimitsDto,
} from './dto/care.dto';

/**
 * Round 15 "My care". `?forUserId=` = the family caregiver acting for that
 * member (CaregiverAccessService). Skipping the sign-up step and the
 * emergency "Alert family" button are the user's own actions only.
 */
@Controller('care')
export class CareController {
  constructor(
    private readonly care: CareService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  private acting(userId: string, forUserId?: string) {
    return this.caregivers.resolve(userId, forUserId);
  }

  @Get()
  async overview(
    @CurrentUser('id') userId: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.overview((await this.acting(userId, forUserId)).subjectId);
  }

  @Put('conditions')
  async setConditions(
    @CurrentUser('id') userId: string,
    @Body() dto: SetConditionsDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.setConditions(await this.acting(userId, forUserId), dto);
  }

  @Post('step-skip')
  @HttpCode(HttpStatus.OK)
  skipStep(@CurrentUser('id') userId: string) {
    return this.care.skipStep(userId);
  }

  @Put('limits')
  async updateLimits(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateLimitsDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.updateLimits(await this.acting(userId, forUserId), dto);
  }

  @Put('settings/:code')
  async updateSetting(
    @CurrentUser('id') userId: string,
    @Param('code') code: string,
    @Body() dto: CareSettingDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.updateSetting(await this.acting(userId, forUserId), code, dto);
  }

  @Put('ticks')
  async setTick(
    @CurrentUser('id') userId: string,
    @Body() dto: SetTickDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.setTick(await this.acting(userId, forUserId), dto);
  }

  @Post('logs')
  async createLog(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateCareLogDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.createLog(await this.acting(userId, forUserId), dto);
  }

  @Delete('logs/:id')
  async deleteLog(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.deleteLog(await this.acting(userId, forUserId), id);
  }

  @Post('questions')
  async addQuestion(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateQuestionDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.addQuestion(await this.acting(userId, forUserId), dto);
  }

  @Delete('questions/:id')
  async deleteQuestion(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.care.deleteQuestion(await this.acting(userId, forUserId), id);
  }

  @Post('alert-family')
  @HttpCode(HttpStatus.OK)
  alertFamily(@CurrentUser('id') userId: string) {
    return this.care.alertFamily(userId);
  }
}
