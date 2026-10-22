import { BadRequestException } from '@nestjs/common';
import { memoryStorage } from 'multer';

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic']);
const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024; // 15MB

/**
 * In-memory storage for a single uploaded prescription image: Multer
 * parses the multipart body into a buffer, which `CloudinaryService`
 * then uploads directly -- no intermediate write to local disk, and no
 * file survives past the request. One file per upload request.
 */
export const prescriptionImageMulterOptions = {
  storage: memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE_BYTES },
  fileFilter: (_req: unknown, file: Express.Multer.File, callback: (error: Error | null, accept: boolean) => void) => {
    if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
      callback(new BadRequestException('Prescription image must be JPEG, PNG, WEBP, or HEIC'), false);
      return;
    }
    callback(null, true);
  },
};
