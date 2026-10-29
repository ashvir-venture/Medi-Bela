import { BadRequestException } from '@nestjs/common';

/** Admin lists: Next / Previous, 20 rows. */
export const ADMIN_PAGE_SIZE = 20;
/** User lists: "Load more", 10 rows. */
export const USER_PAGE_SIZE = 10;

export interface CursorPage<T> {
  items: T[];
  /** Pass back as `cursor` for the next page; null on the last page. */
  nextCursor: string | null;
}

interface CursorKey {
  createdAt: Date;
  id: string;
}

/**
 * Keyset ("cursor") pagination over (createdAt DESC, id DESC): stable while
 * rows are being added, and cheap at any depth (no OFFSET scan). The cursor
 * is opaque to clients. Admin "Previous" works by keeping the cursors of
 * pages already seen on the client.
 *
 * Usage:
 *   const rows = await prisma.x.findMany({ where: { ...filters, ...cursorWhere(cursor) },
 *     orderBy: CURSOR_ORDER, take: pageSize + 1 });
 *   return toCursorPage(rows, pageSize);
 */
export const CURSOR_ORDER = [{ createdAt: 'desc' as const }, { id: 'desc' as const }];

export function encodeCursor(row: CursorKey): string {
  return Buffer.from(JSON.stringify([row.createdAt.toISOString(), row.id])).toString('base64url');
}

export function decodeCursor(cursor: string | undefined | null): CursorKey | null {
  if (!cursor) return null;
  try {
    const [iso, id] = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
    const createdAt = new Date(iso);
    if (typeof id !== 'string' || !id || Number.isNaN(createdAt.getTime())) throw new Error('bad cursor');
    return { createdAt, id };
  } catch {
    throw new BadRequestException('Invalid cursor');
  }
}

/** Prisma `where` fragment selecting rows strictly after the cursor. */
export function cursorWhere(cursor: string | undefined | null) {
  const key = decodeCursor(cursor);
  if (!key) return {};
  return {
    OR: [{ createdAt: { lt: key.createdAt } }, { createdAt: key.createdAt, id: { lt: key.id } }],
  };
}

/** Rows must be fetched with `take: pageSize + 1` and CURSOR_ORDER. */
export function toCursorPage<T extends CursorKey>(rows: T[], pageSize: number): CursorPage<T> {
  const items = rows.slice(0, pageSize);
  return {
    items,
    nextCursor: rows.length > pageSize ? encodeCursor(items[items.length - 1]) : null,
  };
}
