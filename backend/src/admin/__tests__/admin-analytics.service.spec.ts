import { AdminAnalyticsService, buckets } from '../admin-analytics.service';

describe('buckets', () => {
  it('lists every lookup row (zeros included) and folds null keys into notSet', () => {
    const result = buckets(
      [
        { id: 1, name: 'Dhaka' },
        { id: 2, name: 'Khulna' },
      ],
      [
        [1, 5],
        [null, 2],
      ],
    );
    expect(result).toEqual({
      rows: [
        { id: 1, name: 'Dhaka', count: 5 },
        { id: 2, name: 'Khulna', count: 0 },
      ],
      notSet: 2,
    });
  });
});

describe('AdminAnalyticsService ranked lists', () => {
  function ranked(n: number, from = 0) {
    return Array.from({ length: n }, (_, i) => ({
      id: `doc-${from + i}`,
      patients: 100 - from - i,
    }));
  }

  function service(rows: { id: string; patients: number }[]) {
    const prisma: any = {
      $queryRaw: jest.fn().mockResolvedValue(rows),
      doctor: {
        // Returned out of order on purpose: the ranking must be kept.
        findMany: jest.fn(async ({ where }: any) =>
          [...where.id.in].reverse().map((id: string) => ({ id, name: `Dr ${id}`, specialty: null })),
        ),
      },
    };
    return { prisma, svc: new AdminAnalyticsService(prisma) };
  }

  it('pages 20 at a time with ranks and a next cursor', async () => {
    const { svc } = service(ranked(21));
    const page = await svc.listTopDoctors();
    expect(page.items).toHaveLength(20);
    expect(page.items[0]).toMatchObject({
      id: 'doc-0',
      rank: 1,
      patients: 100,
    });
    expect(page.items[19]).toMatchObject({ id: 'doc-19', rank: 20 });
    expect(page.nextCursor).toBe('20');
  });

  it('continues the ranking on the next page and ends with no cursor', async () => {
    const { svc } = service(ranked(3, 20));
    const page = await svc.listTopDoctors('20');
    expect(page.items.map((d) => d.rank)).toEqual([21, 22, 23]);
    expect(page.nextCursor).toBeNull();
  });

  it('serves a repeated request from the cache', async () => {
    const { svc, prisma } = service(ranked(2));
    await svc.listTopDoctors();
    await svc.listTopDoctors();
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
  });
});
