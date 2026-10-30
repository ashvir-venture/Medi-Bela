import { Module } from '@nestjs/common';
import { HealthRemindersController } from './health-reminders.controller';
import { HealthRemindersService } from './health-reminders.service';
import { HealthRecordsController } from './health-records.controller';
import { HealthRecordsService } from './health-records.service';
import { SuggestionRulesController } from './suggestion-rules.controller';
import { SuggestionRulesService } from './suggestion-rules.service';
import { RuleEvaluationService } from './rule-evaluation.service';
import { HealthSuggestionsController } from './health-suggestions.controller';
import { HealthSuggestionsService } from './health-suggestions.service';
import { PharmacistRoutinesController } from './pharmacist-routines.controller';
import { AiSuggestionService } from './ai-suggestion.service';

@Module({
  controllers: [
    HealthRemindersController,
    HealthRecordsController,
    SuggestionRulesController,
    HealthSuggestionsController,
    PharmacistRoutinesController,
  ],
  providers: [
    HealthRemindersService,
    HealthRecordsService,
    SuggestionRulesService,
    RuleEvaluationService,
    HealthSuggestionsService,
    AiSuggestionService,
  ],
  // RuleEvaluationService and HealthSuggestionsService are consumed by
  // PrescriptionsModule right after a prescription is completed -- see
  // PrescriptionsService.complete().
  exports: [RuleEvaluationService, HealthSuggestionsService],
})
export class HealthModule {}
