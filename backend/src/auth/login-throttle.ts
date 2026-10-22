/**
 * Minimal brute-force protection for /auth/login (MVP: in-memory, per
 * process). After MAX_FAILURES wrong attempts for the same phone + client IP
 * inside WINDOW_MS the pair is blocked until the window passes; a successful
 * login clears it. Keyed by phone AND ip so an attacker cannot lock a victim
 * out from elsewhere. For multiple instances use a shared store (Redis) or a
 * gateway rate limit - see the deployment checklist.
 */
const MAX_FAILURES = 8;
const WINDOW_MS = 15 * 60 * 1000;

export class LoginThrottle {
  private readonly failures = new Map<string, number[]>();

  private recent(key: string, now: number): number[] {
    const hits = (this.failures.get(key) ?? []).filter((t) => now - t < WINDOW_MS);
    if (hits.length === 0) this.failures.delete(key);
    else this.failures.set(key, hits);
    return hits;
  }

  isBlocked(key: string, now = Date.now()): boolean {
    return this.recent(key, now).length >= MAX_FAILURES;
  }

  recordFailure(key: string, now = Date.now()): void {
    const hits = this.recent(key, now);
    hits.push(now);
    this.failures.set(key, hits);
    // Opportunistic cleanup so the map cannot grow without bound.
    if (this.failures.size > 10_000) {
      for (const k of this.failures.keys()) this.recent(k, now);
    }
  }

  reset(key: string): void {
    this.failures.delete(key);
  }
}
