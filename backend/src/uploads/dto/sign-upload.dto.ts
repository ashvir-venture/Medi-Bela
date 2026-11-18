import { IsIn } from 'class-validator';
import { UPLOAD_FOLDERS, UploadPurpose } from '../upload-purpose';

export class SignUploadDto {
  @IsIn(Object.keys(UPLOAD_FOLDERS))
  purpose: UploadPurpose;
}
