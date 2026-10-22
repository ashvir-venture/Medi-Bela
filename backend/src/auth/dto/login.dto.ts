import { Transform } from 'class-transformer';
import { IsString, MinLength } from 'class-validator';
import { normalizePhone } from '../../common/utils/phone.util';

export class LoginDto {
  @Transform(({ value }) => (typeof value === 'string' ? normalizePhone(value) : value))
  @IsString()
  phone: string;

  @IsString()
  @MinLength(1)
  password: string;
}
