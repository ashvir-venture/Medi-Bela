import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsUUID,
  Matches,
  Min,
  ValidateNested,
} from 'class-validator';

const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/; // HH:mm, 24h

/**
 * What the patient (or caregiver) may change on one medicine line before
 * confirming: dose times (same count), start date, meal timing, or remove
 * the line. Dose amount, strength and duration stay as the pharmacist set them.
 */
export class ConfirmLineDto {
  @IsUUID()
  id: string;

  @IsOptional()
  @IsBoolean()
  remove?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(12)
  @Matches(TIME_REGEX, { each: true, message: 'each scheduleTimes entry must be HH:mm (24h)' })
  scheduleTimes?: string[];

  /** YYYY-MM-DD, today or later. */
  @IsOptional()
  @IsDateString({ strict: true })
  startDate?: string;

  /** A meal_timings row; null clears it. */
  @IsOptional()
  @IsInt()
  @Min(1)
  mealTimingId?: number | null;
}

export class ConfirmPrescriptionDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => ConfirmLineDto)
  lines?: ConfirmLineDto[];
}
