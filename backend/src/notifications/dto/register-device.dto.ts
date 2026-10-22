import { DevicePlatform } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @MinLength(20)
  @MaxLength(4096)
  token: string;

  @IsEnum(DevicePlatform)
  platform: DevicePlatform;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  appVersion?: string;

  /** Sent on FCM token refresh so the superseded token is removed. */
  @IsOptional()
  @IsString()
  @MinLength(20)
  @MaxLength(4096)
  previousToken?: string;
}

export class UnregisterDeviceDto {
  @IsString()
  @MinLength(20)
  @MaxLength(4096)
  token: string;
}
