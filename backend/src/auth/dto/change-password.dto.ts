import { IsString, MaxLength, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString()
  currentPassword: string;

  @IsString()
  @MinLength(6, {
    message: 'newPassword must be at least 6 characters long',
  })
  @MaxLength(72)
  newPassword: string;
}
