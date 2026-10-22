import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Sends one SMS through an HTTP gateway configured by env vars:
 *   SMS_API_URL   endpoint that accepts a JSON POST
 *   SMS_API_KEY   sent as `Authorization: Bearer <key>`
 *   SMS_SENDER_ID optional sender name/number
 * Body sent: { to, message, sender }. Gateways differ (SSL Wireless, BulkSMSBD,
 * Twilio, ...): adapt `send()` below to your provider's request format.
 *
 * Without a gateway: in production nothing is sent (and an error is logged);
 * outside production the message is logged so the flow can be developed locally.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  private readonly url?: string;
  private readonly apiKey?: string;
  private readonly sender?: string;
  private readonly production: boolean;

  constructor(config: ConfigService) {
    this.url = config.get<string>('SMS_API_URL') || undefined;
    this.apiKey = config.get<string>('SMS_API_KEY') || undefined;
    this.sender = config.get<string>('SMS_SENDER_ID') || undefined;
    this.production = config.get<string>('NODE_ENV') === 'production';
  }

  isConfigured(): boolean {
    return !!this.url && !!this.apiKey;
  }

  /** Resolves true if the gateway accepted the message. Never throws. */
  async send(to: string, message: string): Promise<boolean> {
    if (!this.isConfigured()) {
      if (this.production) {
        this.logger.error('SMS gateway not configured (SMS_API_URL / SMS_API_KEY): message not sent');
        return false;
      }
      this.logger.warn(`[DEV, no SMS gateway] to ${to}: ${message}`);
      return true;
    }
    try {
      const response = await fetch(this.url!, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${this.apiKey}` },
        body: JSON.stringify({ to, message, sender: this.sender }),
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) {
        this.logger.error(`SMS gateway returned ${response.status}`); // never log the message (it holds the code)
        return false;
      }
      return true;
    } catch (err) {
      this.logger.error(`SMS gateway request failed: ${(err as Error).name}`);
      return false;
    }
  }
}
