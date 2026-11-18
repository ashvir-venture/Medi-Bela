import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { StockKind } from '@prisma/client';

/** Round 18: what a box count is in (a syrup in ml, an inhaler in puffs...). */
export const BOX_UNITS = ['tablet', 'capsule', 'ml', 'spoon', 'drop', 'puff', 'unit', 'dose', 'piece', 'strip', 'pen', 'vial', 'sachet'] as const;
const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

/** How many units of one medicine are in the box now. */
export class MedicineBoxItemDto {
  @IsUUID()
  routineId: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(10000)
  quantity: number;

  /** Round 18: the unit the count is in (default: by the medicine's form). */
  @IsOptional()
  @IsIn(BOX_UNITS)
  unit?: string;

  /** Round 18: remind when this many days are left. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30)
  refillDays?: number;
}

/** Start the box, or Refill: the totals now (each replaces the old count). */
export class SaveMedicineBoxDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => MedicineBoxItemDto)
  items: MedicineBoxItemDto[];
}

/**
 * Round 18 (client point 5): a box item with no reminder: a medicine kept
 * at home, or a care supply (insulin, test strips, needles, lancets...).
 */
export class BoxExtraDto {
  @IsEnum(StockKind)
  kind: StockKind;

  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsIn(BOX_UNITS)
  unit: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100000)
  quantity: number;

  /** How many are used a day (so we can say how long it lasts); null = not sure. */
  @IsOptional()
  @ValidateIf((_o, v) => v !== null)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(1000)
  perDay?: number | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30)
  refillDays?: number;
}

export class UpdateBoxExtraDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsIn(BOX_UNITS)
  unit?: string;

  /** A new count ("Bought" / Refill): counted from now. */
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100000)
  quantity?: number;

  @IsOptional()
  @ValidateIf((_o, v) => v !== null)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(1000)
  perDay?: number | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30)
  refillDays?: number;
}
