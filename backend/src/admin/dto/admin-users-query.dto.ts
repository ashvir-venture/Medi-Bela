import { AccountStatus, Role } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsIn, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { AGE_BANDS } from '../admin-analytics.service';

export class AdminUsersQueryDto {
  /** Opaque cursor from the previous page's nextCursor. */
  @IsOptional()
  @IsString()
  cursor?: string;

  /** 01…, +8801… or part of a number. */
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  divisionId?: number;

  @IsOptional()
  @IsIn(AGE_BANDS as unknown as string[])
  ageBand?: (typeof AGE_BANDS)[number];

  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  /** Deleted accounts are listed only when asked for. */
  @IsOptional()
  @IsEnum(AccountStatus)
  status?: AccountStatus;
}
