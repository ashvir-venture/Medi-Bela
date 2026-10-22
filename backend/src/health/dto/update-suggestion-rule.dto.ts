import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { SUPPORTED_CONDITION_TYPES } from '../lib/suggestion-rule-conditions';

export class UpdateSuggestionRuleDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(150)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @IsOptional()
  @IsIn(SUPPORTED_CONDITION_TYPES)
  conditionType?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  conditionValue?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  suggestedAction?: string;

  // No `enabled` field here either — see CreateSuggestionRuleDto.
}
