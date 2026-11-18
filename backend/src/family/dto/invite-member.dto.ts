import { IsInt, IsOptional, IsString, Matches, Min } from 'class-validator';
import { Transform } from 'class-transformer';
import { cleanPhone } from '../../common/utils/phone.util';
import { PHONE_MESSAGE, PHONE_REGEX } from '../../common/constants/phone.constant';

export class InviteMemberDto {
  // Stored as typed (spaces and dashes dropped), no +880 added.
  @Transform(({ value }) => (typeof value === 'string' ? cleanPhone(value) : value))
  @IsString()
  @Matches(PHONE_REGEX, { message: PHONE_MESSAGE })
  phone: string;

  /** Owner 2026-11-18: what the inviter calls this person (a relationships id). */
  @IsOptional()
  @IsInt()
  @Min(1)
  relationshipId?: number;
}
