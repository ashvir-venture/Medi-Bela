import { Module } from '@nestjs/common';
import { FamilyModule } from '../family/family.module';
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
import { TestReminderJob } from './test-reminder.job';
import { PersonalRemindersController } from './personal-reminders.controller';
import { PersonalRemindersService } from './personal-reminders.service';

@Module({
  imports: [FamilyModule],
  controllers: [
    PersonalRemindersController,
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
    TestReminderJob,
    PersonalRemindersService,
  ],
  // RuleEvaluationService and HealthSuggestionsService are consumed by
  // PrescriptionsModule right after a prescription is completed -- see
  // PrescriptionsService.complete().
  exports: [RuleEvaluationService, HealthSuggestionsService],
})
export class HealthModule {}
