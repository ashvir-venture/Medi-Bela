import {
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
import { normalizePhone } from '../../common/utils/phone.util';
import { PHONE_REGEX } from '../../common/constants/phone.constant';

export class RegisterDto {
  @Transform(({ value }) => (typeof value === 'string' ? normalizePhone(value) : value))
  @IsString()
  @Matches(PHONE_REGEX, {
    message: 'phone must be a valid phone number, e.g. +8801XXXXXXXXX',
  })
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
}
