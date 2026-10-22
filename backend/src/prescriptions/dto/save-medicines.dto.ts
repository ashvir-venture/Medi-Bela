import { Type } from 'class-transformer';
import { IsArray, ValidateNested } from 'class-validator';
import { MedicineEntryDto } from './medicine-entry.dto';

export class SaveMedicinesDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => MedicineEntryDto)
  medicines: MedicineEntryDto[];
}
