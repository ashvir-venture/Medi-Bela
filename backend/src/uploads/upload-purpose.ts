import { BadRequestException } from '@nestjs/common';

/** Round 18: what a direct upload is for, and the Cloudinary folder it lands in. */
export const UPLOAD_FOLDERS = {
  prescription: 'prescriptions',
  record: 'records',
  pack: 'packs',
} as const;

export type UploadPurpose = keyof typeof UPLOAD_FOLDERS;

const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

/** The public id the server picks: <folder>/<owner user id>/<random uuid>. */
export function uploadPublicId(purpose: UploadPurpose, subjectId: string, id: string): string {
  return `${UPLOAD_FOLDERS[purpose]}/${subjectId}/${id}`;
}

/**
 * A public id the phone sends back must be one the server could have
 * signed for this user and purpose; anything else is refused (no way to
 * attach someone else's photo, or a file from another folder).
 */
export function assertOwnUpload(purpose: UploadPurpose, subjectId: string, publicId: string): void {
  const re = new RegExp(`^${UPLOAD_FOLDERS[purpose]}/${subjectId}/${UUID}$`);
  if (!re.test(publicId)) throw new BadRequestException('Unknown upload');
}
