import { Transform, Type } from 'class-transformer';
import { AppointmentKind, OwnTestStatus } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/;
const CODE_REGEX = /^[a-z0-9_]{1,40}$/;
const orNull = () => ValidateIf((_o, v) => v !== null);

export class DoctorSearchDto {
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  q: string;
}

/** A doctor the patient types: private to them ("my doctors"). */
export class NewDoctorDto {
  @Transform(trim) @IsString() @MinLength(1) @MaxLength(100) name: string;
  @IsOptional() @Transform(trim) @IsString() @MaxLength(150) chamber?: string;
  @IsOptional() @Transform(trim) @IsString() @MaxLength(100) area?: string;
}

/**
 * Which doctor: a catalog doctor (doctorId), one of mine (myDoctorId), a new
 * one of mine (newDoctor), or none. At most one is accepted.
 */
class DoctorChoice {
  @IsOptional() @orNull() @IsUUID() doctorId?: string | null;
  @IsOptional() @orNull() @IsUUID() myDoctorId?: string | null;
  @IsOptional() @ValidateNested() @Type(() => NewDoctorDto) newDoctor?: NewDoctorDto;
}

export class CreateAppointmentDto extends DoctorChoice {
  @IsOptional() @IsEnum(AppointmentKind) kind?: AppointmentKind;
  @IsDateString({ strict: true }) date: string;
  @IsOptional() @orNull() @Matches(TIME_REGEX) time?: string | null;
  @IsOptional() @orNull() @Matches(CODE_REGEX) conditionCode?: string | null;
  @IsOptional() @orNull() @IsInt() @Min(1) @Max(20) number?: number | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(300) note?: string | null;
  @IsOptional() @IsBoolean() remind?: boolean;
}

export class UpdateAppointmentDto extends DoctorChoice {
  @IsOptional() @IsDateString({ strict: true }) date?: string;
  @IsOptional() @orNull() @Matches(TIME_REGEX) time?: string | null;
  @IsOptional() @orNull() @Matches(CODE_REGEX) conditionCode?: string | null;
  @IsOptional() @orNull() @IsInt() @Min(1) @Max(20) number?: number | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(300) note?: string | null;
  @IsOptional() @IsBoolean() remind?: boolean;
  /** Mark a check-up or session done (true) or not done (false). */
  @IsOptional() @IsBoolean() done?: boolean;
}

export class TestValueDto {
  /** A field of the test kind (its code), or a value named by the user. */
  @IsOptional() @Matches(CODE_REGEX) fieldCode?: string;
  @IsOptional() @Transform(trim) @IsString() @MinLength(1) @MaxLength(60) name?: string;
  @IsOptional() @orNull() @IsNumber({ allowNaN: false, allowInfinity: false }) @Min(-1000) @Max(1000000) value?: number | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(30) textValue?: string | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(20) unit?: string | null;
}

export class CreateOwnTestDto {
  /** A test kind (lookup code); without one, otherName names it ("Other"). */
  @IsOptional() @Matches(CODE_REGEX) testKindCode?: string;
  @IsOptional() @Transform(trim) @IsString() @MinLength(1) @MaxLength(80) otherName?: string;
  @IsOptional() @IsEnum(OwnTestStatus) status?: OwnTestStatus;
  @IsDateString({ strict: true }) date: string;
  @IsOptional() @IsBoolean() remind?: boolean;
  @IsOptional() @IsBoolean() fasting?: boolean;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(1000) findings?: string | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(120) lab?: string | null;
  @IsOptional() @orNull() @Matches(CODE_REGEX) conditionCode?: string | null;
  /** The prescription test reminder this result answers. */
  @IsOptional() @orNull() @IsUUID() healthReminderId?: string | null;
  @IsOptional() @IsArray() @ArrayMaxSize(30) @ValidateNested({ each: true }) @Type(() => TestValueDto) values?: TestValueDto[];
}

export class UpdateOwnTestDto {
  @IsOptional() @IsEnum(OwnTestStatus) status?: OwnTestStatus;
  @IsOptional() @IsDateString({ strict: true }) date?: string;
  @IsOptional() @IsBoolean() remind?: boolean;
  @IsOptional() @IsBoolean() fasting?: boolean;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(1000) findings?: string | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(120) lab?: string | null;
  @IsOptional() @orNull() @Matches(CODE_REGEX) conditionCode?: string | null;
  /** Sent = replaces all values. */
  @IsOptional() @IsArray() @ArrayMaxSize(30) @ValidateNested({ each: true }) @Type(() => TestValueDto) values?: TestValueDto[];
}

export class CreateRecordPrescriptionDto extends DoctorChoice {
  @IsDateString({ strict: true }) date: string;
  @IsOptional() @orNull() @Matches(CODE_REGEX) conditionCode?: string | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(500) note?: string | null;
}

export class UpdateRecordPrescriptionDto extends DoctorChoice {
  @IsOptional() @IsDateString({ strict: true }) date?: string;
  @IsOptional() @orNull() @Matches(CODE_REGEX) conditionCode?: string | null;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(500) note?: string | null;
}
