import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { CreateDoctorDto } from '../../catalog/dto/catalog.dto';

/** One test with its reminder details (all optional but the test). */
export class PrescriptionTestEntryDto {
  @IsUUID()
  testId: string;

  /** YYYY-MM-DD; empty = 3 days after the patient confirms. */
  @IsOptional()
  @IsDateString({ strict: true })
  date?: string | null;

  /** HH:mm; empty = 08:00. */
  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):([0-5]\d)$/, { message: 'time must be HH:mm (24h)' })
  time?: string | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  mealTimingId?: number | null;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MaxLength(300)
  note?: string | null;
}

/**
 * The prescription-level part of the pharmacist form: doctor block,
 * visit date, diagnosis, next visit and tests. Doctor: pick an existing
 * one (`doctorId`), type a new one (`doctor`, which creates a Doctor row),
 * or tick Not applicable (`doctorNotApplicable`, no row, doctor cleared).
 */
export class SavePrescriptionDetailsDto {
  @IsOptional()
  @IsUUID()
  doctorId?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => CreateDoctorDto)
  doctor?: CreateDoctorDto;

  @IsOptional()
  @IsBoolean()
  doctorNotApplicable?: boolean;

  /** YYYY-MM-DD; null clears it. */
  @IsOptional()
  @IsDateString({ strict: true })
  visitDate?: string | null;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MaxLength(1000)
  diagnosis?: string | null;

  @IsOptional()
  @IsDateString({ strict: true })
  nextVisitDate?: string | null;

  /** Replaces the prescription's test list (no reminder details; older panels). */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('all', { each: true })
  testIds?: string[];

  /** Replaces the test list with reminder details; wins over testIds. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => PrescriptionTestEntryDto)
  tests?: PrescriptionTestEntryDto[];
}
