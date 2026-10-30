import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { SuggestionStatus } from '@prisma/client';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

class CursorQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;

  /** Medicine name, patient name or phone (contains, ignoring case). */
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  q?: string;
}

/** GET /pharmacist/routines: 20 per page, newest first. */
export class RoutineListQueryDto extends CursorQueryDto {
  /** Only routines that are still running. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  active?: boolean;
}

/** GET /pharmacist/health-suggestions: 20 per page, newest first. */
export class HealthSuggestionListQueryDto extends CursorQueryDto {
  @IsOptional()
  @IsIn(Object.values(SuggestionStatus))
  status?: SuggestionStatus;
}
