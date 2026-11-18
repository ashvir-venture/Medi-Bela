import { IsOptional, IsString, MaxLength } from 'class-validator';

/** Round 18: the app sends its refresh token in the body; the panel's comes in a cookie. */
export class RefreshDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  refreshToken?: string;
}
