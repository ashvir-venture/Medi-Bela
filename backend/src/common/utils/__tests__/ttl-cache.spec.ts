import { TtlCache } from '../ttl-cache';

describe('TtlCache', () => {
  let t = 0;
  const now = () => t;

  beforeEach(() => {
    t = 0;
  });

  it('serves the cached value until it expires, then loads again', async () => {
    const cache = new TtlCache<number>(1000, 10, now);
    const load = jest.fn().mockResolvedValueOnce(1).mockResolvedValueOnce(2);
    expect(await cache.get('k', load)).toBe(1);
    t = 999;
    expect(await cache.get('k', load)).toBe(1);
    t = 1000;
    expect(await cache.get('k', load)).toBe(2);
    expect(load).toHaveBeenCalledTimes(2);
  });

  it('shares one load between concurrent callers', async () => {
    const cache = new TtlCache<number>(1000, 10, now);
    const load = jest.fn().mockResolvedValue(7);
    const [a, b] = await Promise.all([cache.get('k', load), cache.get('k', load)]);
    expect([a, b]).toEqual([7, 7]);
    expect(load).toHaveBeenCalledTimes(1);
  });

  it('does not keep a failed load', async () => {
    const cache = new TtlCache<number>(1000, 10, now);
    await expect(cache.get('k', () => Promise.reject(new Error('db down')))).rejects.toThrow('db down');
    expect(await cache.get('k', async () => 3)).toBe(3);
  });

  it('stays within its size limit', async () => {
    const cache = new TtlCache<number>(1000, 2, now);
    await cache.get('a', async () => 1);
    await cache.get('b', async () => 2);
    await cache.get('c', async () => 3);
    const reload = jest.fn().mockResolvedValue(10);
    expect(await cache.get('a', reload)).toBe(10); // 'a' was evicted
    expect(await cache.get('c', reload)).toBe(3);
  });
});
