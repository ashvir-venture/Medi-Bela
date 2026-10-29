import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { CreateDoctorDto } from '../../catalog/dto/catalog.dto';

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

  /** Replaces the prescription's test list. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('all', { each: true })
  testIds?: string[];
}
