import { ConfigService } from '@nestjs/config';
import { lastValueFrom, of } from 'rxjs';
import {
  CloudinaryService,
  parseCloudinaryImageUrl,
  SIGNED_URL_TTL_SECONDS,
} from '../lib/cloudinary.service';
import { PrescriptionImageUrlInterceptor } from '../lib/prescription-image-url.interceptor';

const PRIVATE_URL = 'https://res.cloudinary.com/demo/image/authenticated/v1699/prescriptions/abc123.jpg';
const PUBLIC_URL = 'https://res.cloudinary.com/demo/image/upload/v1699/prescriptions/old.jpg';

function makeService(configured = true): CloudinaryService {
  const env: Record<string, string> = configured
    ? { CLOUDINARY_CLOUD_NAME: 'demo', CLOUDINARY_API_KEY: 'key', CLOUDINARY_API_SECRET: 'secret' }
    : {};
  return new CloudinaryService({ get: (k: string) => env[k] } as unknown as ConfigService);
}

describe('parseCloudinaryImageUrl', () => {
  it('reads private and public URLs, with or without a signature segment', () => {
    expect(parseCloudinaryImageUrl(PRIVATE_URL)).toEqual({
      type: 'authenticated',
      publicId: 'prescriptions/abc123',
      format: 'jpg',
    });
    expect(
      parseCloudinaryImageUrl('https://res.cloudinary.com/demo/image/authenticated/s--Ab_12--/v1/prescriptions/x.png'),
    ).toEqual({ type: 'authenticated', publicId: 'prescriptions/x', format: 'png' });
    expect(parseCloudinaryImageUrl(PUBLIC_URL)?.type).toBe('upload');
    expect(parseCloudinaryImageUrl('https://evil.example.com/image/authenticated/v1/a.jpg')).toBeNull();
  });
});

describe('CloudinaryService.signedImageUrl', () => {
  it('turns a private image into an expiring signed download link', () => {
    const now = Date.UTC(2026, 9, 28, 8);
    const url = new URL(makeService().signedImageUrl(PRIVATE_URL, now));

    expect(url.hostname).toBe('api.cloudinary.com');
    expect(url.pathname).toBe('/v1_1/demo/image/download');
    expect(url.searchParams.get('public_id')).toBe('prescriptions/abc123');
    expect(url.searchParams.get('type')).toBe('authenticated');
    expect(url.searchParams.get('signature')).toBeTruthy();
    expect(Number(url.searchParams.get('expires_at'))).toBe(now / 1000 + SIGNED_URL_TTL_SECONDS);
    expect(url.toString()).not.toContain('secret');
  });

  it('returns older public images and foreign URLs unchanged', () => {
    const service = makeService();
    expect(service.signedImageUrl(PUBLIC_URL)).toBe(PUBLIC_URL);
    expect(service.signedImageUrl('https://img.test/a.jpg')).toBe('https://img.test/a.jpg');
  });
});

describe('PrescriptionImageUrlInterceptor', () => {
  const cloudinary = { signedImageUrl: (u: string) => `signed:${u}` } as unknown as CloudinaryService;
  const interceptor = new PrescriptionImageUrlInterceptor(cloudinary);
  const run = (body: unknown) => lastValueFrom(interceptor.intercept({} as never, { handle: () => of(body) }));

  it('signs a single prescription and every item of a list', async () => {
    expect(await run({ id: 'p1', imageUrl: 'a' })).toEqual({ id: 'p1', imageUrl: 'signed:a' });
    expect(await run([{ imageUrl: 'a' }, { imageUrl: 'b' }])).toEqual([
      { imageUrl: 'signed:a' },
      { imageUrl: 'signed:b' },
    ]);
  });

  it('leaves other responses alone', async () => {
    expect(await run({ success: true })).toEqual({ success: true });
    expect(await run(null)).toBeNull();
  });
});
