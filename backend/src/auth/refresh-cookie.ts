import type { CookieOptions, Request, Response } from 'express';
import { ConfigService } from '@nestjs/config';

/** Round 18: the panel's refresh token. httpOnly (page scripts can't read it),
 * Secure, SameSite=None by default because the panel (Vercel) and the API
 * (Render) are on different sites; only sent to /api/auth. */
export const REFRESH_COOKIE = 'mb_refresh';

function options(config: ConfigService, maxAgeMs?: number): CookieOptions {
  const sameSite = (config.get<string>('REFRESH_COOKIE_SAMESITE', 'none') as 'none' | 'lax' | 'strict');
  return {
    httpOnly: true,
    secure: config.get<string>('REFRESH_COOKIE_SECURE', 'true') !== 'false',
    sameSite,
    path: '/api/auth',
    ...(maxAgeMs !== undefined ? { maxAge: maxAgeMs } : {}),
  };
}

export function setRefreshCookie(res: Response, config: ConfigService, token: string, expiresAt: Date): void {
  res.cookie(REFRESH_COOKIE, token, options(config, Math.max(0, expiresAt.getTime() - Date.now())));
}

export function clearRefreshCookie(res: Response, config: ConfigService): void {
  res.clearCookie(REFRESH_COOKIE, options(config));
}

/** Reads one cookie from the header (no cookie-parser dependency). */
export function readRefreshCookie(req: Request): string | undefined {
  const header = req.headers.cookie;
  if (!header) return undefined;
  for (const part of header.split(';')) {
    const eq = part.indexOf('=');
    if (eq < 0) continue;
    if (part.slice(0, eq).trim() === REFRESH_COOKIE) {
      try {
        return decodeURIComponent(part.slice(eq + 1).trim()) || undefined;
      } catch {
        return undefined;
      }
    }
  }
  return undefined;
}
