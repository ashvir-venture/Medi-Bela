import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/; // HH:mm, 24h
const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

/** A medicine the patient (or caregiver) adds without a prescription. */
export class CreateRoutineDto {
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  medicineName: string;

  /** Picked from the catalog; omitted = typed name (a catalog stub is made). */
  @IsOptional()
  @IsUUID()
  medicineId?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  strength?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  doseAmount?: string;

  @IsInt()
  @Min(1)
  @Max(12)
  timesPerDay: number;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(12)
  @Matches(TIME_REGEX, { each: true, message: 'each scheduleTimes entry must be HH:mm (24h)' })
  scheduleTimes: string[];

  @IsOptional()
  @IsInt()
  @Min(1)
  mealTimingId?: number;

  /** Round 16: the condition this medicine is for (a conditions.code). */
  @IsOptional()
  @Matches(/^[a-z0-9_]{1,40}$/)
  conditionCode?: string;

  /** Required unless continuous. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  durationDays?: number;

  @IsOptional()
  @IsBoolean()
  continuous?: boolean;

  /** Every N days (1 = every day, the default). */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  intervalDays?: number;

  /** A medicine_forms row (Tablet, Syrup...). */
  @IsOptional()
  @IsInt()
  @Min(1)
  formId?: number;

  /** YYYY-MM-DD, today or later; default today (tomorrow for every N days). */
  @IsOptional()
  @IsDateString({ strict: true })
  startDate?: string;
}

/**
 * Changes to a routine. A pharmacist's medicine accepts only dose times
 * (same count), meal timing and every N days; a self-added one accepts
 * every field.
 */
export class UpdateRoutineDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  medicineName?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  strength?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  doseAmount?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  timesPerDay?: number;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(12)
  @Matches(TIME_REGEX, { each: true, message: 'each scheduleTimes entry must be HH:mm (24h)' })
  scheduleTimes?: string[];

  /** null clears it. */
  @IsOptional()
  @IsInt()
  @Min(1)
  mealTimingId?: number | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  durationDays?: number;

  @IsOptional()
  @IsBoolean()
  continuous?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  intervalDays?: number;

  /** null clears it. Self-added medicines only. */
  @IsOptional()
  @IsInt()
  @Min(1)
  formId?: number | null;
}

/** Round 16: tag a medicine with one of the user's conditions (null = none). */
export class SetRoutineConditionDto {
  @ValidateIf((_o, v) => v !== null)
  @Matches(/^[a-z0-9_]{1,40}$/)
  conditionCode: string | null;
}
