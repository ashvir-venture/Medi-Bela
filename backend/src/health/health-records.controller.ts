import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { HealthRecordsService } from './health-records.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateHealthRecordDto } from './dto/create-health-record.dto';
import { UpdateHealthRecordDto } from './dto/update-health-record.dto';

@Controller('health-records')
export class HealthRecordsController {
  constructor(private readonly records: HealthRecordsService) {}

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateHealthRecordDto) {
    return this.records.create(userId, dto);
  }

  @Get()
  list(@CurrentUser('id') userId: string) {
    return this.records.list(userId);
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
