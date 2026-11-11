import { Transform, Type } from 'class-transformer';
import { CareLogKind, SugarUnit } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsIn,
  IsInt,
  IsISO8601,
  IsNumber,
  IsObject,
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
/** Nullable optional: undefined = keep, null = clear. */
const orNull = () => ValidateIf((_o, v) => v !== null);

export class SetConditionsDto {
  @IsArray()
  @ArrayMaxSize(20)
  @Matches(CODE_REGEX, { each: true })
  codes: string[];
}

/** The doctor's numbers (Round 15). Sugar values in mmol/L. */
export class UpdateLimitsDto {
  @IsOptional() @IsEnum(SugarUnit) sugarUnit?: SugarUnit;
  @IsOptional() @orNull() @IsNumber() @Min(1) @Max(30) fastingLow?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(1) @Max(30) fastingHigh?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(1) @Max(30) afterFoodHigh?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(1) @Max(30) lowSugar?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(4) @Max(14) hba1cTarget?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(90) @Max(200) bpSystolicHigh?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(50) @Max(130) bpDiastolicHigh?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(60) @Max(130) bpSystolicLow?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(140) @Max(220) bpCrisisSystolic?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(90) @Max(140) bpCrisisDiastolic?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(100) @Max(800) peakFlowBest?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(0.5) @Max(5) weightGain3Days?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(0.01) @Max(10) tshLow?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(0.1) @Max(20) tshHigh?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(0) @Max(5000) fluidLimitMl?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(98) @Max(104) feverAboveF?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(20) @Max(200) weightGoalKg?: number | null;
  @IsOptional() @orNull() @IsInt() @Min(1) @Max(20) waterGlasses?: number | null;
  @IsOptional() @orNull() @IsNumber() @Min(3) @Max(12) sleepHours?: number | null;
  @IsOptional() @IsBoolean() notifyFamily?: boolean;
  @IsOptional() @orNull() @Transform(trim) @IsString() @MaxLength(120) doctorNote?: string | null;
}

class PenDto {
  @IsDateString({ strict: true }) openedOn: string;
  @IsInt() @Min(1) @Max(90) lifeDays: number;
  @IsInt() @Min(0) @Max(14) remindDaysBefore: number;
}

class BirthPlanDto {
  @IsOptional() @Transform(trim) @IsString() @MaxLength(120) hospital?: string;
  @IsOptional() @Transform(trim) @IsString() @MaxLength(120) transport?: string;
  @IsOptional() @Transform(trim) @IsString() @MaxLength(20) bloodGroup?: string;
  @IsOptional() @Transform(trim) @IsString() @MaxLength(120) donor?: string;
  @IsOptional() @Transform(trim) @IsString() @MaxLength(120) companion?: string;
  @IsOptional() @IsBoolean() moneySetAside?: boolean;
}

export const ASTHMA_TRIGGERS = ['dust', 'smoke', 'cook', 'coil', 'cold', 'pollen', 'pet'] as const;
export const TEST_EVERY_MONTHS = [0, 1, 3, 6, 12] as const;

/**
 * One condition's settings and care plan. Every field is optional; a PUT
 * replaces only the fields it sends (null clears one). Fields that don't
 * belong to the condition are rejected by the service.
 */
export class CareSettingDto {
  // The care plan (every condition): habits ticked daily, regular tests.
  @IsOptional() @IsArray() @ArrayMaxSize(20) @Matches(CODE_REGEX, { each: true }) habits?: string[];
  /** Habits the user typed: key -> text. */
  @IsOptional() @IsObject() customHabits?: Record<string, string>;
  @IsOptional() @IsArray() @ArrayMaxSize(20) @Matches(CODE_REGEX, { each: true }) tests?: string[];
  /** Test kind code -> how often in months (0 = as the doctor advises). */
  @IsOptional() @IsObject() testEveryMonths?: Record<string, number>;

  // diabetes
  @IsOptional() @orNull() @ValidateNested() @Type(() => PenDto) pen?: PenDto | null;
  // pregnancy
  @IsOptional() @orNull() @IsDateString({ strict: true }) dueDate?: string | null;
  @IsOptional() @orNull() @IsNumber() @Min(20) @Max(200) startWeightKg?: number | null;
  @IsOptional() @ValidateNested() @Type(() => BirthPlanDto) birthPlan?: BirthPlanDto;
  // asthma
  @IsOptional() @IsArray() @IsIn(ASTHMA_TRIGGERS as unknown as string[], { each: true }) triggers?: string[];
  // kidney
  @IsOptional() @IsBoolean() dialysis?: boolean;
  @IsOptional() @IsArray() @ArrayMaxSize(7) @IsInt({ each: true }) @Min(0, { each: true }) @Max(6, { each: true }) dialysisDays?: number[];
  @IsOptional() @orNull() @Matches(TIME_REGEX) dialysisTime?: string | null;
  // cancer
  @IsOptional() @orNull() @IsInt() @Min(1) @Max(50) chemoTotal?: number | null;
  @IsOptional() @IsInt() @Min(0) @Max(50) chemoDone?: number;
}

export class SetTickDto {
  /** "habit:<key>" or "asthma_night". */
  @Matches(/^(habit:[a-z0-9_]{1,40}|asthma_night)$/)
  key: string;

  @IsDateString({ strict: true })
  day: string;

  @IsBoolean()
  done: boolean;
}

export class CreateCareLogDto {
  @IsEnum(CareLogKind)
  kind: CareLogKind;

  @IsOptional()
  @Matches(CODE_REGEX)
  conditionCode?: string;

  @IsOptional()
  @IsISO8601()
  loggedAt?: string;

  /** The kind's fields; checked by the service (CareService.checkLogData). */
  @IsObject()
  data: Record<string, unknown>;

  @IsOptional()
  @IsUUID()
  clientId?: string;
}

export class CreateQuestionDto {
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(300)
  text: string;
}
