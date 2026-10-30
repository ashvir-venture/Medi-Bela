import { Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { RoutineListQueryDto } from './dto/pharmacist-list-query.dto';
import { HealthSuggestionsService } from './health-suggestions.service';

/** Pharmacist routine panel: see generated routines, and ask for an AI suggestion per routine (never automatic). */
@Controller('pharmacist/routines')
@Roles(Role.PHARMACIST)
export class PharmacistRoutinesController {
  constructor(private readonly suggestions: HealthSuggestionsService) {}

  /** ?q=&active=true&cursor= ; 20 per page, newest first. */
  @Get()
  list(@Query() query: RoutineListQueryDto) {
    return this.suggestions.listRoutines(query);
  }

  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.getRoutine(id);
  }

  /** Explicit pharmacist action: one model call, returns the new/updated DRAFT. Publishing is a separate step. */
  @Post(':id/suggestion')
  request(@CurrentUser('id') actorId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.suggestions.requestForRoutine(actorId, id);
  }
}
