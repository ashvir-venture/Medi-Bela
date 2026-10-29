import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
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
}
