import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { Language } from '@prisma/client';

// Intentionally excludes `phone` and `role`: phone changes affect family
// lookups/uniqueness and role changes are an admin action, not a
// self-service profile edit. Both are out of scope for this endpoint.
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;

  @IsOptional()
  @IsEnum(Language)
  languagePreference?: Language;

  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  profileVisibleToFamily?: boolean;

  /** Off: no medicine reminders on the phone, no backstop push, and no missed-dose family alerts. */
  @IsOptional()
  @IsBoolean()
  medicineRemindersEnabled?: boolean;

  /** Round 14: easy mode for elders (big text, today's medicine, one Taken, call family). */
  @IsOptional()
  @IsBoolean()
  easyMode?: boolean;

  /** Off: notices still appear in the app, but are not pushed. */
  @IsOptional()
  @IsBoolean()
  noticesEnabled?: boolean;

  // "Edit your details". Address levels change together (all three).

  /** YYYY-MM-DD */
  @IsOptional()
  @IsDateString({ strict: true })
  dateOfBirth?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  genderId?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  divisionId?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  districtId?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  upazilaId?: number;

  /** Round 15: optional height in cm (BMI on weight readings); null clears it. */
  @IsOptional()
  @ValidateIf((_o, v) => v !== null)
  @IsInt()
  @Min(50)
  @Max(250)
  heightCm?: number | null;
}
