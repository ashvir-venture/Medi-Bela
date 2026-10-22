import { IsString, MaxLength, MinLength } from 'class-validator';

export class RejectPrescriptionDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  rejectionReason: string;
}
