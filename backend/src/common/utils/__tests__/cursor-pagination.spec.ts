import { BadRequestException } from '@nestjs/common';
import { cursorWhere, decodeCursor, encodeCursor, toCursorPage } from '../cursor-pagination';

const row = (n: number) => ({ id: `id-${n}`, createdAt: new Date(Date.UTC(2026, 9, 29, 0, 0, 60 - n)) });

describe('cursor pagination', () => {
  it('round-trips a cursor', () => {
    const r = row(3);
    expect(decodeCursor(encodeCursor(r))).toEqual({ id: r.id, createdAt: r.createdAt });
  });

  it('a page of size n from n+1 rows has a next cursor at its last item', () => {
    const page = toCursorPage([row(1), row(2), row(3)], 2);
    expect(page.items.map((r) => r.id)).toEqual(['id-1', 'id-2']);
    expect(decodeCursor(page.nextCursor)?.id).toBe('id-2');
  });

  it('the last page has no next cursor', () => {
    expect(toCursorPage([row(1)], 2).nextCursor).toBeNull();
  });

  it('selects rows strictly after the cursor, ties broken by id', () => {
    const r = row(2);
    expect(cursorWhere(encodeCursor(r))).toEqual({
      OR: [{ createdAt: { lt: r.createdAt } }, { createdAt: r.createdAt, id: { lt: r.id } }],
    });
    expect(cursorWhere(undefined)).toEqual({});
  });

  it('rejects a tampered cursor with 400', () => {
    expect(() => decodeCursor('not-a-cursor')).toThrow(BadRequestException);
  });
});
