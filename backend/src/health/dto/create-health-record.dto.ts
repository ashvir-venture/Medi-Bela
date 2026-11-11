import { BpArm, HealthRecordType, InjectionGiver, InjectionSite, SugarContext } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * A type, a display value, an optional unit/notes, and when it was recorded.
 * `value` stays a free-text string (e.g. "120/80") so older app versions keep
 * working. Round 15 adds optional structured fields; the service checks the
 * ones each type needs when they are sent (see HealthRecordsService):
 * - BLOOD_PRESSURE: systolic, diastolic (the average of 1-2 measurements),
 *   pulse, bpArm, measurements
 * - BLOOD_SUGAR: numericValue in mmol/L, sugarContext
 * - WEIGHT kg, TEMPERATURE °F, SLEEP hours, WATER glasses, PEAK_FLOW L/min:
 *   numericValue
 * - INSULIN: numericValue = units, injectionSite, injectionGiver, doseId
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

  @IsOptional()
  @IsNumber({ allowNaN: false, allowInfinity: false })
  numericValue?: number;

  @IsOptional()
  @IsInt()
  @Min(50)
  @Max(260)
  systolic?: number;

  @IsOptional()
  @IsInt()
  @Min(30)
  @Max(160)
  diastolic?: number;

  @IsOptional()
  @IsInt()
  @Min(20)
  @Max(250)
  pulse?: number;

  @IsOptional()
  @IsEnum(BpArm)
  bpArm?: BpArm;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(2)
  measurements?: number;

  @IsOptional()
  @IsEnum(SugarContext)
  sugarContext?: SugarContext;

  @IsOptional()
  @IsEnum(InjectionSite)
  injectionSite?: InjectionSite;

  @IsOptional()
  @IsEnum(InjectionGiver)
  injectionGiver?: InjectionGiver;

  /** The insulin dose this injection was given for. */
  @IsOptional()
  @IsUUID()
  doseId?: string;
}
