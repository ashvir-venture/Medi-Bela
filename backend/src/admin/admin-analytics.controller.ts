import { Controller, Get, Param, ParseIntPipe, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { AdminAnalyticsService } from './admin-analytics.service';
import { RankedListQueryDto } from './dto/analytics-query.dto';

/** Numbers are cached for 5 minutes; each response carries generatedAt. */
@Controller('admin/analytics')
@Roles(Role.ADMIN)
export class AdminAnalyticsController {
  constructor(private readonly analytics: AdminAnalyticsService) {}

  @Get()
  overview() {
    return this.analytics.getOverview();
  }

  /** Users per district inside one division. */
  @Get('divisions/:id')
  division(@Param('id', ParseIntPipe) id: number) {
    return this.analytics.getDivision(id);
  }

  @Get('top-doctors')
  topDoctors(@Query() query: RankedListQueryDto) {
    return this.analytics.listTopDoctors(query.cursor);
  }

  @Get('top-medicines')
  topMedicines(@Query() query: RankedListQueryDto) {
    return this.analytics.listTopMedicines(query.cursor);
  }
}
