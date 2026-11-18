import { BadRequestException } from '@nestjs/common';
import { v2 as cloudinary } from 'cloudinary';
import { assertOwnUpload, uploadPublicId } from '../upload-purpose';
import { CloudinaryService, DIRECT_UPLOAD_MAX_BYTES } from '../../prescriptions/lib/cloudinary.service';

const USER = '11111111-2222-3333-4444-555555555555';
const OTHER = '99999999-2222-3333-4444-555555555555';
const FILE = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

describe('direct uploads (Round 18)', () => {
  it('the server picks <folder>/<user>/<uuid>', () => {
    expect(uploadPublicId('prescription', USER, FILE)).toBe(`prescriptions/${USER}/${FILE}`);
    expect(uploadPublicId('pack', USER, FILE)).toBe(`packs/${USER}/${FILE}`);
  });

  it('only the user own upload of that purpose is accepted', () => {
    expect(() => assertOwnUpload('prescription', USER, `prescriptions/${USER}/${FILE}`)).not.toThrow();
    for (const bad of [
      `prescriptions/${OTHER}/${FILE}`, // someone else's
      `records/${USER}/${FILE}`, // another purpose
      `prescriptions/${USER}/${FILE}/../x`,
      `prescriptions/${USER}/not-a-uuid`,
      `x/prescriptions/${USER}/${FILE}`,
    ]) {
      expect(() => assertOwnUpload('prescription', USER, bad)).toThrow(BadRequestException);
    }
  });

  describe('CloudinaryService', () => {
    const config = {
      get: (k: string) => ({ CLOUDINARY_CLOUD_NAME: 'demo', CLOUDINARY_API_KEY: 'key', CLOUDINARY_API_SECRET: 'secret' })[k],
      getOrThrow: (k: string) => ({ CLOUDINARY_CLOUD_NAME: 'demo', CLOUDINARY_API_KEY: 'key', CLOUDINARY_API_SECRET: 'secret' })[k],
    };
    const service = new CloudinaryService(config as any);

    it('signs a private, JPG / PNG only upload at the given public id; the secret is not sent', () => {
      const signed = service.signDirectUpload(`packs/${USER}/${FILE}`, 1_700_000_000_000);
      expect(signed).toMatchObject({
        uploadUrl: 'https://api.cloudinary.com/v1_1/demo/image/upload',
        apiKey: 'key',
        timestamp: 1_700_000_000,
        publicId: `packs/${USER}/${FILE}`,
        type: 'authenticated',
        maxBytes: DIRECT_UPLOAD_MAX_BYTES,
      });
      expect(JSON.stringify(signed)).not.toContain('secret');
      const expected = cloudinary.utils.api_sign_request(
        { timestamp: 1_700_000_000, public_id: `packs/${USER}/${FILE}`, type: 'authenticated', allowed_formats: 'jpg,jpeg,png' },
        'secret',
      );
      expect(signed.signature).toBe(expected);
    });

    it('refuses and removes an upload that is too big or not a photo', async () => {
      const resource = jest.spyOn(cloudinary.api, 'resource').mockResolvedValue({ format: 'pdf', bytes: 1000, version: 1, public_id: 'x' } as any);
      const destroy = jest.spyOn(cloudinary.uploader, 'destroy').mockResolvedValue({} as any);
      await expect(service.confirmDirectUpload('x')).rejects.toMatchObject({ status: 400 });
      expect(destroy).toHaveBeenCalled();
      resource.mockResolvedValue({ format: 'jpg', bytes: DIRECT_UPLOAD_MAX_BYTES + 1, version: 1, public_id: 'x' } as any);
      await expect(service.confirmDirectUpload('x')).rejects.toMatchObject({ status: 400 });
      resource.mockResolvedValue({ format: 'jpg', bytes: 50_000, version: 7, public_id: 'x' } as any);
      await expect(service.confirmDirectUpload('x')).resolves.toContain('/image/authenticated/');
      resource.mockRejectedValue(new Error('not found'));
      await expect(service.confirmDirectUpload('x')).rejects.toThrow('The photo was not uploaded');
      resource.mockRestore();
      destroy.mockRestore();
    });
  });
});
