import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsNumber, IsUUID, Max, Min, ValidateNested } from 'class-validator';

/** How many units of one medicine are in the box now. */
export class MedicineBoxItemDto {
  @IsUUID()
  routineId: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(10000)
  quantity: number;
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
