import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { HealthSuggestionsService } from './health-suggestions.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UpdateHealthSuggestionDto } from './dto/update-health-suggestion.dto';
import { HealthSuggestionListQueryDto } from './dto/pharmacist-list-query.dto';

@Controller()
export class HealthSuggestionsController {
  constructor(private readonly suggestions: HealthSuggestionsService) {}

  // --- User-facing: only ever published suggestions -------------------

  @Get('health-suggestions/mine')
  getMine(@CurrentUser('id') userId: string) {
    return this.suggestions.getMine(userId);
  }

  // --- Pharmacist: review and publish ----------------------------------

  /** ?status=DRAFT|PUBLISHED&q=&cursor= ; 20 per page, newest first. */
  @Get('pharmacist/health-suggestions')
  @Roles(Role.PHARMACIST)
  list(@Query() query: HealthSuggestionListQueryDto) {
    return this.suggestions.list(query);
  }

  @Get('pharmacist/health-suggestions/:id')
  @Roles(Role.PHARMACIST)
  getDetail(@Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.getDetail(id);
  }

  @Patch('pharmacist/health-suggestions/:id')
  @Roles(Role.PHARMACIST)
  update(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateHealthSuggestionDto,
  ) {
    return this.suggestions.update(actorId, id, dto);
  }

  @Post('pharmacist/health-suggestions/:id/publish')
  @Roles(Role.PHARMACIST)
  publish(@CurrentUser('id') actorId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.publish(actorId, id);
  }

  @Post('pharmacist/health-suggestions/:id/unpublish')
  @Roles(Role.PHARMACIST)
  unpublish(@CurrentUser('id') actorId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.unpublish(actorId, id);
  }
}
