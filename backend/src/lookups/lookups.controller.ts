import { Controller, Get, ParseIntPipe, Query } from '@nestjs/common';
import { LookupsService } from './lookups.service';

/** Read-only dropdown data for any signed-in user (app and admin panel). */
@Controller('lookups')
export class LookupsController {
  constructor(private readonly lookups: LookupsService) {}

  @Get()
  getAll() {
    return this.lookups.getAll();
  }

  @Get('upazilas')
  getUpazilas(@Query('districtId', ParseIntPipe) districtId: number) {
    return this.lookups.getUpazilas(districtId);
  }
}
