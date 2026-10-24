import {
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
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
}
