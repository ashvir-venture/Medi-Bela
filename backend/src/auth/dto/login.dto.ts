import { Transform } from 'class-transformer';
import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class LoginDto {
  // Kept as typed (trimmed): AuthService matches it exactly first, so a seeded
  // phone stored as written in .env signs in (see AuthService.findUserByPhone).
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  phone: string;

  @IsString()
  @MinLength(1)
  password: string;

  /** Round 18: 'panel' = the management panel (7-day refresh token in an httpOnly cookie); default the app. */
  @IsOptional()
  @IsIn(['app', 'panel'])
  client?: 'app' | 'panel';
}
