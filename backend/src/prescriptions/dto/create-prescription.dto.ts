import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

/**
 * Body fields alongside the multipart `image` file. `clientId` mirrors
 * the mobile app's `PrescriptionApi.uploadDraft` idempotency key — see
 * `Prescription.clientUploadId`.
 */
export class CreatePrescriptionDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  clientId?: string;

  // Accepted for forward-compatibility with the mobile client (which
  // currently sends a free-text `note` alongside the image) but not
  // persisted: the Prescription model has no user-facing note field in
  // this phase. Kept optional/whitelisted so the upload doesn't fail
  // validation.
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;

  /** Re-upload: the user's own REJECTED prescription this one replaces. */
  @IsOptional()
  @IsUUID()
  previousPrescriptionId?: string;
}
