import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/; // HH:mm, 24h

/**
 * One medicine line item entered/corrected by an admin/pharmacist while
 * processing a prescription. `timesPerDay`/`scheduleTimes`/`durationDays`
 * are optional while the prescription is still PENDING (the admin may
 * save progress incrementally) but are required — and cross-validated —
 * before the prescription can be COMPLETED. See
 * `PrescriptionsService.assertMedicinesReadyForCompletion`.
 */
export class MedicineEntryDto {
  /** Present when editing an existing PrescriptionMedicine; absent when adding a new one. */
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  medicineName: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  dosage: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  frequency: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  duration: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  instructions?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  timesPerDay?: number;

  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateIf((o) => o.scheduleTimes !== undefined)
  @Matches(TIME_REGEX, { each: true, message: 'each scheduleTimes entry must be HH:mm (24h)' })
  scheduleTimes?: string[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  durationDays?: number;

  @IsOptional()
  @Type(() => Date)
  startDate?: Date;
}
