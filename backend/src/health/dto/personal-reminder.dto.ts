import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/; // HH:mm, 24h
const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

/** A reminder the user (or their caregiver) sets up: name, what, times. */
export class CreatePersonalReminderDto {
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name: string;

  /** What to remind, shown under "Time for your {name}". */
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(300)
  description?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(12)
  @Matches(TIME_REGEX, { each: true, message: 'each scheduleTimes entry must be HH:mm (24h)' })
  scheduleTimes: string[];

  /** Every N days (1 = every day). */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  intervalDays?: number;

  /** YYYY-MM-DD, today or later; default today. */
  @IsOptional()
  @IsDateString({ strict: true })
  startDate?: string;

  /** YYYY-MM-DD; none = until removed. */
  @IsOptional()
  @IsDateString({ strict: true })
  endDate?: string | null;
}

export class UpdatePersonalReminderDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(300)
  description?: string | null;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(12)
  @Matches(TIME_REGEX, { each: true, message: 'each scheduleTimes entry must be HH:mm (24h)' })
  scheduleTimes?: string[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  intervalDays?: number;

  @IsOptional()
  @IsDateString({ strict: true })
  endDate?: string | null;
}

/** Later on one ring: [at] is that ring's time (one caregiver alert per ring). */
export class PersonalReminderLaterDto {
  @IsOptional()
  @IsDateString()
  at?: string;
}
