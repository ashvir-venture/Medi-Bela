import { IsString, MaxLength, ValidateIf } from 'class-validator';

/** Round 18: a directly uploaded pack photo (public id), or null to remove it. */
export class PackPhotoDto {
  @ValidateIf((_o, v) => v !== null)
  @IsString()
  @MaxLength(200)
  publicId: string | null;
}
