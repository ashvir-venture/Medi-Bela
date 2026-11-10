import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { OWN_TIMING_LIMITS as L } from '../../common/config/reminder-timing';

/**
 * Round 14: the user's own reminder timings. A field left out keeps its
 * value; null goes back to the .env default.
 */
export class UpdateReminderTimingDto {
  @IsOptional()
  @IsInt()
  @Min(L.repeatMinutes.min)
  @Max(L.repeatMinutes.max)
  repeatMinutes?: number | null;

  @IsOptional()
  @IsInt()
  @Min(L.laterMinutes.min)
  @Max(L.laterMinutes.max)
  laterMinutes?: number | null;

  @IsOptional()
  @IsInt()
  @Min(L.rings.min)
  @Max(L.rings.max)
  rings?: number | null;

  @IsOptional()
  @IsInt()
  @Min(L.familyAlertMinutes.min)
  @Max(L.familyAlertMinutes.max)
  familyAlertMinutes?: number | null;
}
