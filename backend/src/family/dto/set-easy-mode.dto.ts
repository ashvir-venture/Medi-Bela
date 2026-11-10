import { IsBoolean } from 'class-validator';

/** Round 14: the caregiver switches easy mode for a member. */
export class SetEasyModeDto {
  @IsBoolean()
  on!: boolean;
}
