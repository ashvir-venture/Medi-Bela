import { Transform } from 'class-transformer';
import { IsString, MinLength } from 'class-validator';

export class LoginDto {
  // Kept as typed (trimmed): AuthService matches it exactly first, so a seeded
  // phone stored as written in .env signs in (see AuthService.findUserByPhone).
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  phone: string;

  @IsString()
  @MinLength(1)
  password: string;
}
