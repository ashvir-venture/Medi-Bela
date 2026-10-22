import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsString, MaxLength, MinLength, ValidateNested } from 'class-validator';

class SuggestionItemDto {
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  category: string;

  @IsString()
  @MinLength(1)
  @MaxLength(300)
  text: string;
}

/**
 * Lets an admin edit the AI-generated draft before publishing -- the
 * model's output is a starting point, never shown to the user until a
 * human has had the chance to correct/trim it.
 */
export class UpdateHealthSuggestionDto {
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => SuggestionItemDto)
  itemsEn: SuggestionItemDto[];

  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => SuggestionItemDto)
  itemsBn: SuggestionItemDto[];
}
