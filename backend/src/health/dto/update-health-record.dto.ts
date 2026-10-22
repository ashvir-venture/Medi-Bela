import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/** See `HealthRecordsService.update` for why `type`/`recordedAt` are excluded. */
export class UpdateHealthRecordDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  value?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  unit?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
