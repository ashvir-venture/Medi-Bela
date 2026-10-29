import { Controller, Get, Param, ParseBoolPipe, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { HealthSuggestionsService } from './health-suggestions.service';

/** Admin routine panel: see generated routines, and ask for an AI suggestion per routine (never automatic). */
@Controller('admin/routines')
@Roles(Role.ADMIN)
export class AdminRoutinesController {
  constructor(private readonly suggestions: HealthSuggestionsService) {}

  @Get()
  list(
    @Query('userId', new ParseUUIDPipe({ optional: true })) userId?: string,
    @Query('active', new ParseBoolPipe({ optional: true })) active?: boolean,
  ) {
    return this.suggestions.listRoutinesForAdmin({ userId, active });
  }

  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.getRoutineForAdmin(id);
  }

  /** Explicit admin action: one model call, returns the new/updated DRAFT. Publishing is a separate step. */
  @Post(':id/suggestion')
  request(@Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.requestForRoutine(id);
  }
}
