/**
 * Verifies push configuration against the REAL Firebase project, without delivering anything.
 *
 *   npx ts-node scripts/check-push.ts                 # config + credentials check
 *   npx ts-node scripts/check-push.ts <fcmToken>      # + FCM dry-run for that device token
 *
 * Reads the same env vars as the server (.env is loaded if present). Exit code 0 = OK.
 */
import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { ConfigService } from '@nestjs/config';
import { TokenCryptoService } from '../src/notifications/token-crypto.service';

try {
  process.loadEnvFile(); // Node >= 20.12: reads ./.env if present
} catch {
  /* no .env file: rely on the real environment */
}

const ok = (m: string) => console.log(`  OK   ${m}`);
const fail = (m: string) => {
  console.log(`  FAIL ${m}`);
  process.exitCode = 1;
};

async function main() {
  console.log('1. Token encryption key (PUSH_TOKEN_ENC_KEY)');
  try {
    const crypto = new TokenCryptoService({ getOrThrow: (k: string) => { const v = process.env[k]; if (!v) throw new Error(`${k} is not set`); return v; } } as unknown as ConfigService);
    ok(crypto.decrypt(crypto.encrypt('probe-token')) === 'probe-token' ? 'valid 32-byte key; encrypt/decrypt round-trips' : 'round-trip mismatch');
  } catch (e) {
    fail((e as Error).message);
  }

  console.log('2. Firebase credentials');
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  let app;
  try {
    if (b64 || json) {
      const sa = JSON.parse(b64 ? Buffer.from(b64, 'base64').toString('utf8') : (json as string));
      ok(`service account parsed (project: ${sa.project_id ?? 'unknown'})`);
      app = initializeApp({ credential: cert(sa) });
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      app = initializeApp({ credential: applicationDefault() });
      ok('using GOOGLE_APPLICATION_CREDENTIALS');
    } else {
      fail('no credentials set (FIREBASE_SERVICE_ACCOUNT_BASE64 / _JSON / GOOGLE_APPLICATION_CREDENTIALS): the server will DISABLE push and mark every notification SKIPPED');
      return;
    }
    const token = await app.options.credential!.getAccessToken();
    ok(token.access_token ? 'Google accepted the credentials (access token issued)' : 'no access token returned');
  } catch (e) {
    fail(`credentials rejected: ${(e as Error).message}`);
    return;
  }

  const fcmToken = process.argv[2];
  console.log('3. FCM dry-run');
  if (!fcmToken) {
    console.log('  SKIP pass a device token to also validate delivery to a real device');
    return;
  }
  try {
    await getMessaging(app).send({ token: fcmToken, notification: { title: 'Medi-Bela', body: 'dry run' } }, true);
    ok('FCM accepted the message for this token (dry run, nothing delivered)');
  } catch (e) {
    fail(`FCM rejected it: ${(e as { code?: string }).code ?? ''} ${(e as Error).message}`);
  }
}

main().catch((e) => fail((e as Error).message));
