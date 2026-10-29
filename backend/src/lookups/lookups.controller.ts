import { Controller, Get, ParseIntPipe, Query } from '@nestjs/common';
import { LookupsService } from './lookups.service';
import { Public } from '../common/decorators/public.decorator';

/**
 * Read-only dropdown data (app and admin panel). Public since Round 6: the
 * registration form needs it before there is an account. Rate-limited per
 * IP like every public route.
 */
@Public()
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
