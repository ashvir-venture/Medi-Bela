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
  Max,
  MaxLength,
  Min,
  MinLength,
  IsString,
  ValidateNested,
} from 'class-validator';

const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/; // HH:mm, 24h

/**
 * What the patient (or caregiver) may change on one medicine line before
 * confirming: dose times (same count), start date, meal timing, every N
 * days, or remove the line. Dose amount, strength and duration stay as the pharmacist set them.
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

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  intervalDays?: number;
}

export class ConfirmPrescriptionDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => ConfirmLineDto)
  lines?: ConfirmLineDto[];
}

/** "Request edit": the prescription goes back to the pharmacist with this note. */
export class RequestEditDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  note: string;
}
