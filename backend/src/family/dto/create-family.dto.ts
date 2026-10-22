import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateFamilyDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;
}
