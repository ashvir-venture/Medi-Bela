import {
  Equals,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Language } from '@prisma/client';
import { Transform } from 'class-transformer';
import { cleanPhone } from '../../common/utils/phone.util';
import { PHONE_MESSAGE, PHONE_REGEX } from '../../common/constants/phone.constant';

export class RegisterDto {
  // Stored as typed (spaces and dashes dropped), no +880 added.
  @Transform(({ value }) => (typeof value === 'string' ? cleanPhone(value) : value))
  @IsString()
  @Matches(PHONE_REGEX, { message: PHONE_MESSAGE })
  phone: string;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;

  @IsString()
  @MinLength(6, { message: 'password must be at least 6 characters long' })
  @MaxLength(72) // bcrypt/argon2 practical input limit
  password!: string;
  
  @IsOptional()
  @IsEnum(Language)
  languagePreference?: Language;

  // --- Required since Round 6 (checked against the lookup tables) ---

  /** YYYY-MM-DD */
  @IsDateString({ strict: true })
  dateOfBirth: string;

  @IsInt()
  @Min(1)
  genderId: number;

  @IsInt()
  @Min(1)
  divisionId: number;

  @IsInt()
  @Min(1)
  districtId: number;

  @IsInt()
  @Min(1)
  upazilaId: number;

  /** Round 11: the Privacy & terms box, ticked. Recorded as users.termsAcceptedAt. */
  @IsBoolean()
  @Equals(true, { message: 'You must agree to the Privacy & terms' })
  acceptTerms: boolean;
}
