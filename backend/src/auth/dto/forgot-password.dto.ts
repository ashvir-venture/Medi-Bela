import { Transform } from 'class-transformer';
import { IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { normalizePhone } from '../../common/utils/phone.util';

const phone = () => Transform(({ value }) => (typeof value === 'string' ? normalizePhone(value) : value));

export class ForgotPasswordDto {
  @phone()
  @IsString()
  phone: string;
}

export class ResetPasswordDto {
  @phone()
  @IsString()
  phone: string;

  /** The 6-digit code received by SMS. */
  @IsString()
  @Matches(/^\d{6}$/, { message: 'code must be 6 digits' })
  code: string;

  @IsString()
  @MinLength(6, { message: 'newPassword must be at least 6 characters long' })
  @MaxLength(72)
  newPassword: string;
}
