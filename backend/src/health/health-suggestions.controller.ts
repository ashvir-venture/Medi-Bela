import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { Role } from '@prisma/client';
import { HealthSuggestionsService } from './health-suggestions.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UpdateHealthSuggestionDto } from './dto/update-health-suggestion.dto';

@Controller()
export class HealthSuggestionsController {
  constructor(private readonly suggestions: HealthSuggestionsService) {}

  // --- User-facing: only ever published suggestions -------------------

  @Get('health-suggestions/mine')
  getMine(@CurrentUser('id') userId: string) {
    return this.suggestions.getMine(userId);
  }

  // --- Admin -----------------------------------------------------------

  @Get('admin/health-suggestions')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  list() {
    return this.suggestions.listForAdmin();
  }

  @Get('admin/health-suggestions/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  getDetail(@Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.getDetail(id);
  }

  @Patch('admin/health-suggestions/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateHealthSuggestionDto) {
    return this.suggestions.update(id, dto);
  }

  @Post('admin/health-suggestions/:id/publish')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  publish(@CurrentUser('id') adminId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.publish(adminId, id);
  }

  @Post('admin/health-suggestions/:id/unpublish')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  unpublish(@Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.unpublish(id);
  }
}
