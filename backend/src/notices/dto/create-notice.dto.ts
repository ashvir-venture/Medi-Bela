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
} from 'class-validator';

export class CreateNoticeDto {
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  content: string;

  @IsOptional()
  @IsEnum(NoticeAudience)
  audience?: NoticeAudience;

  @IsOptional()
  @IsISO8601()
  expiresAt?: string;

  /** Where the information comes from, shown with the notice (e.g. "DGHS"). */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  source?: string;

  /** Link to the original announcement (https only). */
  @IsOptional()
  @IsUrl({ protocols: ['https'], require_protocol: true })
  @MaxLength(500)
  sourceUrl?: string;

  /** Scheduled publishing: hidden (and not pushed) until this time. */
  @IsOptional()
  @IsISO8601()
  startsAt?: string;

  /** lookup `divisions` ids; empty or omitted = every division. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsInt({ each: true })
  @Min(1, { each: true })
  divisionIds?: number[];

  // No `status` field here on purpose: every new notice starts as a DRAFT.
  // A pharmacist submits it for approval; an admin publishes it (their own
  // directly, a pharmacist's after review).
}
