import { Body, Controller, Get, Param, ParseEnumPipe, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { HealthRecordType } from '@prisma/client';
import { HealthRecordsService } from './health-records.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';
import { CreateHealthRecordDto } from './dto/create-health-record.dto';
import { UpdateHealthRecordDto } from './dto/update-health-record.dto';

/** `?forUserId=` = the family caregiver acting for that member (Round 15). */
@Controller('health-records')
export class HealthRecordsController {
  constructor(
    private readonly records: HealthRecordsService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  @Post()
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateHealthRecordDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.create(await this.caregivers.resolve(userId, forUserId), dto);
  }

  @Get()
  async list(
    @CurrentUser('id') userId: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
    @Query('type', new ParseEnumPipe(HealthRecordType, { optional: true })) type?: HealthRecordType,
  ) {
    const acting = await this.caregivers.resolve(userId, forUserId);
    return this.records.list(acting.subjectId, type);
  }

  @Get(':id')
  getDetail(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.records.getDetail(userId, id);
  }

  @Patch(':id')
  update(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateHealthRecordDto,
  ) {
    return this.records.update(userId, id, dto);
  }
}
