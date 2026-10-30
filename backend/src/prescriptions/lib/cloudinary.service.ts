import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary } from 'cloudinary';

/**
 * Uploads prescription images to Cloudinary using a backend-held API
 * secret (never exposed to the mobile app or admin panel -- the client
 * sends the raw file to our API, we upload server-side). One file per
 * call, matching the existing single-file upload flow.
 *
 * New uploads are stored as `authenticated` assets: their plain URL returns
 * 401, so the stored `imageUrl` is only a reference. Clients receive a
 * short-lived signed link instead (see `signedImageUrl`, applied by
 * PrescriptionImageUrlInterceptor). Images uploaded before this change are
 * public `upload` assets and are returned unchanged.
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

  /**
   * Uploads one image buffer as a private (authenticated) asset and returns
   * its unsigned URL, which is what gets stored: unlike Cloudinary's own
   * `secure_url` it carries no permanent signature, so a leaked row grants no
   * access on its own.
   */
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
          type: 'authenticated',
          filename_override: originalFilename,
        },
        (error, result) => {
          if (error || !result) {
            this.logger.warn(`Cloudinary upload failed: ${error?.message ?? 'no result'}`);
            reject(new InternalServerErrorException('Failed to upload prescription image'));
            return;
          }
          resolve(
            cloudinary.url(result.public_id, {
              resource_type: 'image',
              type: 'authenticated',
              version: result.version,
              format: result.format,
              secure: true,
            }),
          );
        },
      );
      stream.end(buffer);
    });
  }

  /**
   * Best-effort removal of an image we uploaded (used when an account is
   * deleted). Only touches Cloudinary URLs; never throws.
   */
  /**
   * The link a client may use to view a stored image. Private images get a
   * signed download link that expires after SIGNED_URL_TTL_SECONDS; public
   * (older) images and non-Cloudinary URLs are returned as they are.
   */
  signedImageUrl(storedUrl: string, now = Date.now()): string {
    const parsed = parseCloudinaryImageUrl(storedUrl);
    if (!this.configured || !parsed || parsed.type !== 'authenticated') return storedUrl;
    return cloudinary.utils.private_download_url(parsed.publicId, parsed.format ?? 'jpg', {
      resource_type: 'image',
      type: 'authenticated',
      expires_at: Math.floor(now / 1000) + SIGNED_URL_TTL_SECONDS,
    });
  }

  async deleteImageByUrl(url: string): Promise<void> {
    if (!this.configured) return;
    const parsed = parseCloudinaryImageUrl(url);
    if (!parsed) return;
    try {
      await cloudinary.uploader.destroy(parsed.publicId, {
        resource_type: 'image',
        type: parsed.type,
        invalidate: true,
      });
    } catch {
      this.logger.warn('Cloudinary image deletion failed');
    }
  }
}

/** How long a signed prescription image link stays valid. */
export const SIGNED_URL_TTL_SECONDS = 60 * 60;

export interface CloudinaryImageRef {
  type: 'upload' | 'authenticated';
  publicId: string;
  format: string | null;
}

/**
 * `https://res.cloudinary.com/<cloud>/image/authenticated/v123/prescriptions/abc.jpg`
 * -> `{ type: 'authenticated', publicId: 'prescriptions/abc', format: 'jpg' }`.
 * Accepts `upload` (older, public) and `authenticated` (private) URLs, with or
 * without a `s--signature--` segment. A query string or fragment (the SDK's
 * `cloudinary.url()` appends `?_a=...`, so stored URLs carry one) is not part
 * of the public id and is dropped. Anything else returns null.
 */
export function parseCloudinaryImageUrl(url: string): CloudinaryImageRef | null {
  const path = url.split(/[?#]/, 1)[0];
  const match =
    /^https:\/\/res\.cloudinary\.com\/[^/]+\/image\/(upload|authenticated)\/(?:s--[^/]+--\/)?(?:v\d+\/)?(.+?)(?:\.([A-Za-z0-9]+))?$/.exec(
      path,
    );
  if (!match) return null;
  return {
    type: match[1] as CloudinaryImageRef['type'],
    publicId: match[2],
    format: match[3] ?? null,
  };
}

/** `https://res.cloudinary.com/<cloud>/image/upload/v123/prescriptions/abc.jpg` -> `prescriptions/abc` */
export function cloudinaryPublicId(url: string): string | null {
  return parseCloudinaryImageUrl(url)?.publicId ?? null;
}
