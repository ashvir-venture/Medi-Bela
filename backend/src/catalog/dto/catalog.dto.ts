import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class SearchQueryDto {
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  q: string;
}

export class CatalogListQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;

  /** Prefix filter on the name. */
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  q?: string;

  /** Only rows a pharmacist still has to complete. */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  incomplete?: boolean;
}

export class CreateDoctorDto {
  @Transform(trim)
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  name: string;

  /** BMDC registration number, e.g. "A-12345". */
  @IsOptional()
  @Transform(trim)
  @IsString()
  @Matches(/^[A-Za-z0-9-]{1,30}$/, { message: 'bmdcNumber may only contain letters, digits and -' })
  bmdcNumber?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  specialtyId?: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(300)
  chamber?: string;

  @IsOptional()
  @Transform(trim)
  @Matches(/^\+?[0-9 -]{5,20}$/, { message: 'phone must be digits' })
  phone?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  districtId?: number;
}

/** Every field optional: only the fields sent change. */
export class UpdateDoctorDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(2)
  @MaxLength(150)
  name?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @Matches(/^[A-Za-z0-9-]{1,30}$/, { message: 'bmdcNumber may only contain letters, digits and -' })
  bmdcNumber?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  specialtyId?: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(300)
  chamber?: string;

  @IsOptional()
  @Transform(trim)
  @Matches(/^\+?[0-9 -]{5,20}$/, { message: 'phone must be digits' })
  phone?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  districtId?: number;
}

export class CreateMedicineDto {
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  brandName: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  genericName?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  formId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  categoryId?: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  manufacturer?: string;
}

export class UpdateMedicineDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  brandName?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  genericName?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  formId?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  categoryId?: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  manufacturer?: string;
}

export class CreateTestDto {
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  name: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  categoryId?: number;
}
