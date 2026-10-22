import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, createHmac, randomBytes } from 'crypto';

/**
 * Protects FCM device tokens at rest.
 *
 *  - `hash()`    HMAC-SHA256 — deterministic, used for lookup / uniqueness
 *                so the DB never needs the raw token to find a row.
 *  - `encrypt()` AES-256-GCM with a random IV per value — the only form in
 *                which the raw token is persisted. Decrypted solely inside
 *                the push dispatcher, in memory, at send time.
 *
 * Key: PUSH_TOKEN_ENC_KEY = base64 of 32 random bytes
 *      (`openssl rand -base64 32`). The service refuses to start without it
 *      rather than silently falling back to plaintext storage.
 */
@Injectable()
export class TokenCryptoService {
  private readonly key: Buffer;

  constructor(config: ConfigService) {
    const raw = config.getOrThrow<string>('PUSH_TOKEN_ENC_KEY');
    const key = Buffer.from(raw, 'base64');
    if (key.length !== 32) {
      throw new Error('PUSH_TOKEN_ENC_KEY must be base64 of exactly 32 bytes');
    }
    this.key = key;
  }

  hash(token: string): string {
    return createHmac('sha256', this.key).update(token, 'utf8').digest('hex');
  }

  encrypt(token: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const ciphertext = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return ['v1', iv.toString('base64url'), tag.toString('base64url'), ciphertext.toString('base64url')].join('.');
  }

  decrypt(payload: string): string {
    const [version, iv, tag, ciphertext] = payload.split('.');
    if (version !== 'v1' || !iv || !tag || !ciphertext) {
      throw new Error('Unsupported token payload');
    }
    const decipher = createDecipheriv('aes-256-gcm', this.key, Buffer.from(iv, 'base64url'));
    decipher.setAuthTag(Buffer.from(tag, 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(ciphertext, 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  }
}
