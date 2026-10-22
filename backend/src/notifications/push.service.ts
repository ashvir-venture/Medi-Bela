import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { Messaging, getMessaging } from 'firebase-admin/messaging';

export interface PushMessage {
  title: string;
  body: string;
  /** Flat string map delivered to the app for routing. No health data. */
  data: Record<string, string>;
  /** Same value => the OS replaces rather than stacks a re-delivered message. */
  collapseKey: string;
}

export interface PushSendResult {
  token: string;
  ok: boolean;
  /** Token will never work again (uninstalled / expired) — delete it. */
  permanentTokenFailure: boolean;
  errorCode?: string;
}

const PERMANENT_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export const ANDROID_CHANNEL_ID = 'carebridge_alerts';

/**
 * Thin wrapper around firebase-admin. Credentials come from the environment
 * only (never the repo):
 *   FIREBASE_SERVICE_ACCOUNT_BASE64  base64 of the service-account JSON (preferred)
 *   FIREBASE_SERVICE_ACCOUNT_JSON    the raw JSON
 *   GOOGLE_APPLICATION_CREDENTIALS   path to the JSON file (standard ADC)
 * With none configured, push is disabled (logged loudly at startup) and the
 * rest of the app — including the in-app notification inbox — keeps working.
 */
@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private messaging: Messaging | null = null;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    try {
      const app = this.buildApp();
      if (app) {
        this.messaging = getMessaging(app);
        this.logger.log('FCM push enabled');
      } else {
        this.logger.warn(
          'FCM credentials not configured — push notifications are DISABLED (inbox still works)',
        );
      }
    } catch (err) {
      // Misconfigured credentials must not take the whole API down.
      this.logger.error(`FCM initialisation failed — push disabled: ${(err as Error).message}`);
    }
  }

  isEnabled(): boolean {
    return this.messaging !== null;
  }

  /** At most 500 tokens per call (FCM limit); callers here send ≤ a handful. */
  async send(tokens: string[], message: PushMessage): Promise<PushSendResult[]> {
    if (!this.messaging || tokens.length === 0) return [];

    const response = await this.messaging.sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
      android: {
        priority: 'high',
        collapseKey: message.collapseKey,
        notification: { channelId: ANDROID_CHANNEL_ID, tag: message.collapseKey },
      },
      apns: {
        headers: { 'apns-collapse-id': message.collapseKey.slice(0, 64) },
        payload: { aps: { sound: 'default' } },
      },
    });

    return response.responses.map((r, i) => ({
      token: tokens[i],
      ok: r.success,
      permanentTokenFailure: !r.success && PERMANENT_TOKEN_ERRORS.has(r.error?.code ?? ''),
      errorCode: r.error?.code,
    }));
  }

  private buildApp(): App | null {
    const existing = getApps()[0];
    if (existing) return existing;

    const b64 = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_BASE64');
    const json = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (b64 || json) {
      const raw = b64 ? Buffer.from(b64, 'base64').toString('utf8') : (json as string);
      return initializeApp({ credential: cert(JSON.parse(raw)) });
    }
    if (this.config.get<string>('GOOGLE_APPLICATION_CREDENTIALS')) {
      return initializeApp({ credential: applicationDefault() });
    }
    return null;
  }
}
