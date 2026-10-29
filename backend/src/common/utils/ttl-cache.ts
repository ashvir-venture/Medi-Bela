/**
 * Small in-memory cache for expensive read-only results (admin analytics).
 * Each key holds the loader's promise for `ttlMs`, so concurrent requests
 * share one load; a failed load is dropped so the next request retries.
 * In-memory: correct for the single API instance this app runs.
 */
export class TtlCache<T> {
  private readonly entries = new Map<string, { expiresAt: number; value: Promise<T> }>();

  constructor(
    private readonly ttlMs: number,
    private readonly maxEntries = 500,
    private readonly now: () => number = Date.now,
  ) {}

  get(key: string, load: () => Promise<T>): Promise<T> {
    const t = this.now();
    const hit = this.entries.get(key);
    if (hit && hit.expiresAt > t) return hit.value;

    if (this.entries.size >= this.maxEntries) this.evictExpired(t);
    // Still full of live entries: drop the oldest (Map keeps insertion order).
    if (this.entries.size >= this.maxEntries) {
      const oldest = this.entries.keys().next().value;
      if (oldest !== undefined) this.entries.delete(oldest);
    }

    const value = load();
    this.entries.delete(key);
    this.entries.set(key, { expiresAt: t + this.ttlMs, value });
    value.catch(() => {
      if (this.entries.get(key)?.value === value) this.entries.delete(key);
    });
    return value;
  }

  clear() {
    this.entries.clear();
  }

  private evictExpired(t: number) {
    for (const [key, entry] of this.entries) if (entry.expiresAt <= t) this.entries.delete(key);
  }
}
