import { HealthRecordType } from '@prisma/client';
import { IsEnum, IsISO8601,
  IsUUID, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/**
 * Deliberately minimal per the "no comprehensive EHR" scope restriction:
 * a type, a value, an optional unit/notes, and when it was recorded.
 * `value` is a free-text string rather than a typed number because
 * different record types have different shapes (e.g. blood pressure is
 * "120/80", weight is "68"); the mobile UI is responsible for prompting
 * appropriately per `type`.
 */
export class CreateHealthRecordDto {
  @IsEnum(HealthRecordType)
  type: HealthRecordType;

  @IsString()
  @MinLength(1)
  @MaxLength(50)
  value: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  unit?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;

  @IsOptional()
  @IsISO8601()
  recordedAt?: string;

  /** Offline draft id; makes a retried upload idempotent. */
  @IsOptional()
  @IsUUID()
  clientId?: string;
}
