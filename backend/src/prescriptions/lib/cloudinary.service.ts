import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary } from 'cloudinary';

/**
 * Uploads prescription images to Cloudinary using a backend-held API
 * secret (never exposed to the mobile app or admin panel -- the client
 * sends the raw file to our API, we upload server-side). One file per
 * call, matching the existing single-file upload flow.
 *
 * Configure via env:
 *   CLOUDINARY_CLOUD_NAME
 *   CLOUDINARY_API_KEY
 *   CLOUDINARY_API_SECRET
 */
@Injectable()
export class CloudinaryService {
  private readonly logger = new Logger(CloudinaryService.name);
  private configured = false;

  constructor(private readonly config: ConfigService) {
    const cloudName = this.config.get<string>('CLOUDINARY_CLOUD_NAME');
    const apiKey = this.config.get<string>('CLOUDINARY_API_KEY');
    const apiSecret = this.config.get<string>('CLOUDINARY_API_SECRET');
    this.configured = Boolean(cloudName && apiKey && apiSecret);
    if (this.configured) {
      cloudinary.config({ cloud_name: cloudName, api_key: apiKey, api_secret: apiSecret });
    }
  }

  isConfigured(): boolean {
    return this.configured;
  }

  /** Uploads one image buffer, returns its Cloudinary secure URL. */
  uploadPrescriptionImage(buffer: Buffer, originalFilename: string): Promise<string> {
    if (!this.configured) {
      throw new InternalServerErrorException(
        'File storage is not configured (missing Cloudinary credentials)',
      );
    }

    return new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'prescriptions',
          resource_type: 'image',
          filename_override: originalFilename,
        },
        (error, result) => {
          if (error || !result) {
            this.logger.warn(`Cloudinary upload failed: ${error?.message ?? 'no result'}`);
            reject(new InternalServerErrorException('Failed to upload prescription image'));
            return;
          }
          resolve(result.secure_url);
        },
      );
      stream.end(buffer);
    });
  }

  /**
   * Best-effort removal of an image we uploaded (used when an account is
   * deleted). Only touches Cloudinary URLs; never throws.
   */
  async deleteImageByUrl(url: string): Promise<void> {
    if (!this.configured) return;
    const publicId = cloudinaryPublicId(url);
    if (!publicId) return;
    try {
      await cloudinary.uploader.destroy(publicId, { resource_type: 'image', invalidate: true });
    } catch {
      this.logger.warn('Cloudinary image deletion failed');
    }
  }
}

/** `https://res.cloudinary.com/<cloud>/image/upload/v123/prescriptions/abc.jpg` -> `prescriptions/abc` */
export function cloudinaryPublicId(url: string): string | null {
  const match = /^https:\/\/res\.cloudinary\.com\/[^/]+\/image\/upload\/(?:v\d+\/)?(.+?)(?:\.[A-Za-z0-9]+)?$/.exec(url);
  return match ? match[1] : null;
}
