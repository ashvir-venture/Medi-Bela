import { NoticeAudience } from '@prisma/client';
import { IsEnum, IsISO8601, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

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

  // No `status` field here on purpose: every new notice starts as a
  // DRAFT (see NoticesService.create). Use POST .../:id/publish to go
  // live, matching the health-suggestion-rules publish convention.
}
