import { NoticeAudience } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

/** Every field optional; for the nullable ones `null` clears, omit leaves unchanged. */
export class UpdateNoticeDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  content?: string;

  @IsOptional()
  @IsEnum(NoticeAudience)
  audience?: NoticeAudience;

  /** ISO date to set an expiry, `null` to remove it, omit to leave unchanged. */
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsISO8601()
  expiresAt?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(200)
  source?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsUrl({ protocols: ['https'], require_protocol: true })
  @MaxLength(500)
  sourceUrl?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsISO8601()
  startsAt?: string | null;

  /** Replaces the list; [] = every division. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsInt({ each: true })
  @Min(1, { each: true })
  divisionIds?: number[];
}
