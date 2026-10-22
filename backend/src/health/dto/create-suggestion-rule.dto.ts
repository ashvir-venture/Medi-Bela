import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { SUPPORTED_CONDITION_TYPES } from '../lib/suggestion-rule-conditions';

export class CreateSuggestionRuleDto {
  @IsString()
  @MinLength(1)
  @MaxLength(150)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsIn(SUPPORTED_CONDITION_TYPES)
  conditionType: string;

  /** e.g. "metformin" when conditionType is MEDICINE_NAME_CONTAINS */
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  conditionValue: string;

  /** Becomes the generated HealthReminder's title — kept as plain,
   * reviewable text so an admin can see exactly what a rule produces. */
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  suggestedAction: string;

  // No `enabled` field here on purpose: every new rule starts as a draft
  // (see `SuggestionRulesService.create`). Use POST .../:id/publish to
  // go live.
}
