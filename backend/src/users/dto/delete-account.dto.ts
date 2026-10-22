import { IsString, MinLength } from 'class-validator';

export class DeleteAccountDto {
  /** Re-authentication: the current password is required to delete the account. */
  @IsString()
  @MinLength(1)
  password: string;
}
