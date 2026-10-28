import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable, map } from 'rxjs';
import { CloudinaryService } from './cloudinary.service';

/**
 * Swaps the stored `imageUrl` of every prescription a route returns (one
 * object or an array of them) for a link the client can open: a short-lived
 * signed URL for private images, unchanged for older public ones. Applied to
 * the whole PrescriptionsController so no route can leak a stored reference.
 */
@Injectable()
export class PrescriptionImageUrlInterceptor implements NestInterceptor {
  constructor(private readonly cloudinary: CloudinaryService) {}

  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(map((body) => this.sign(body)));
  }

  private sign(body: unknown): unknown {
    if (Array.isArray(body)) return body.map((item) => this.sign(item));
    if (body && typeof body === 'object' && typeof (body as { imageUrl?: unknown }).imageUrl === 'string') {
      const record = body as { imageUrl: string };
      return { ...record, imageUrl: this.cloudinary.signedImageUrl(record.imageUrl) };
    }
    return body;
  }
}
