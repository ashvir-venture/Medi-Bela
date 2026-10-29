import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsUUID,
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

  // --- Structured line (Round 4); the pharmacist form uses these in Round 5 ---

  /** A row of the Medicine table. */
  @IsOptional()
  @IsUUID()
  medicineId?: string;

  /** Strength lives on the line, e.g. "500 mg". */
  @IsOptional()
  @IsString()
  @MaxLength(50)
  strength?: string;

  /** Amount per dose, e.g. "1 tablet". */
  @IsOptional()
  @IsString()
  @MaxLength(50)
  doseAmount?: string;

  /** A row of the meal_timings table. */
  @IsOptional()
  @IsInt()
  @Min(1)
  mealTimingId?: number;

  /** No end date: durationDays may be omitted and doses keep being generated. */
  @IsOptional()
  @IsBoolean()
  continuous?: boolean;
}
