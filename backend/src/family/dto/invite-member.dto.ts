import { IsString, Matches } from 'class-validator';
import { Transform } from 'class-transformer';
import { normalizePhone } from '../../common/utils/phone.util';
import { PHONE_REGEX } from '../../common/constants/phone.constant';

export class InviteMemberDto {
  @Transform(({ value }) => (typeof value === 'string' ? normalizePhone(value) : value))
  @IsString()
  @Matches(PHONE_REGEX, {
    message: 'phone must be a valid phone number, e.g. +8801XXXXXXXXX',
  })
  phone: string;
}
