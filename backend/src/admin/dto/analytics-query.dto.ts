import { IsOptional, IsString, Matches } from 'class-validator';

export class RankedListQueryDto {
  /** Opaque cursor from the previous page's nextCursor. */
  @IsOptional()
  @IsString()
  @Matches(/^\d{1,6}$/, { message: 'Invalid cursor' })
  cursor?: string;
}
