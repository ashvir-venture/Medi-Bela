import { IsString, MinLength } from 'class-validator';

export class DeleteAccountDto {
  /** Re-authentication: the current password is required to deactivate or delete the account. */
  @IsString()
  @MinLength(1)
  password: string;
}
