import { ExecutionContext } from '@nestjs/common';
import { ThrottlerModuleOptions } from '@nestjs/throttler';
import { createHash } from 'crypto';
import { RequestWithUser } from '../interfaces/request-with-user.interface';

const MINUTE_MS = 60_000;
const DEFAULT_USER_LIMIT = 120;
const DEFAULT_IP_LIMIT = 60;

/** Only the env values this config reads (lets tests pass a plain object). */
export interface RateLimitEnv {
  RATE_LIMIT_ENABLED?: string;
  RATE_LIMIT_USER_PER_MINUTE?: string;
  RATE_LIMIT_IP_PER_MINUTE?: string;
  NODE_ENV?: string;
}

function positiveInt(value: string | undefined, fallback: number): number {
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}

function signedInUser(context: ExecutionContext): string | undefined {
  return context.switchToHttp().getRequest<Partial<RequestWithUser>>().user?.id;
}

/**
 * One global limit across every endpoint, applied by ThrottlerGuard after
 * JwtAuthGuard (so requests rejected with 401 are never counted):
 *  - signed-in requests share one bucket per user id. Many users can sit
 *    behind one mobile-carrier IP, so they're never limited by IP;
 *  - @Public() routes (no request.user) share one bucket per client IP.
 * Counters are in memory, which only works with a single API instance.
 * Off under Jest unless RATE_LIMIT_ENABLED=true; RATE_LIMIT_ENABLED=false
 * turns it off anywhere.
 */
export function rateLimitOptions(env: RateLimitEnv): ThrottlerModuleOptions {
  const enabled =
    env.RATE_LIMIT_ENABLED !== undefined && env.RATE_LIMIT_ENABLED !== ''
      ? env.RATE_LIMIT_ENABLED === 'true'
      : env.NODE_ENV !== 'test';
  const userLimit = positiveInt(env.RATE_LIMIT_USER_PER_MINUTE, DEFAULT_USER_LIMIT);
  const ipLimit = positiveInt(env.RATE_LIMIT_IP_PER_MINUTE, DEFAULT_IP_LIMIT);

  return {
    throttlers: [
      {
        // Named "default" so the 429 carries a plain Retry-After header.
        name: 'default',
        ttl: MINUTE_MS,
        limit: (context) => (signedInUser(context) ? userLimit : ipLimit),
      },
    ],
    skipIf: () => !enabled,
    // request.ip honours TRUST_PROXY (see main.ts); without it every client
    // behind a proxy shares the proxy's address and one bucket.
    getTracker: (req, context) => {
      const userId = signedInUser(context);
      return userId ? `user:${userId}` : `ip:${String(req.ip ?? 'unknown')}`;
    },
    // The stock key includes the controller and handler, i.e. one bucket
    // per route; one bucket per caller makes the limit global.
    generateKey: (_context, tracker, name) =>
      createHash('sha256').update(`${name}-${tracker}`).digest('hex'),
  };
}
