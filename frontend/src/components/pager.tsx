'use client';

import { useCallback, useEffect, useState } from 'react';
import { ApiError, CursorPage } from '@/lib/api-client';

/**
 * Next / Previous over the backend's cursor pages (20 rows). "Previous"
 * works by remembering the cursors of pages already visited. Changing
 * [resetKey] (a filter) starts again at page 1.
 */
export function useCursorPager<T>(
  fetchPage: (cursor: string | null) => Promise<CursorPage<T>>,
  resetKey: string,
) {
  const [cursors, setCursors] = useState<(string | null)[]>([null]);
  const [page, setPage] = useState<CursorPage<T> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [reloadTick, setReloadTick] = useState(0);

  useEffect(() => {
    setCursors([null]);
  }, [resetKey]);

  const cursor = cursors[cursors.length - 1];

  useEffect(() => {
    let cancelled = false;
    setIsLoading(true);
    setError(null);
    fetchPage(cursor)
      .then((p) => {
        if (!cancelled) setPage(p);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof ApiError ? err.message : 'Failed to load');
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });
    return () => {
      cancelled = true;
    };
    // fetchPage changes with the filters, which also change resetKey.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cursor, resetKey, reloadTick]);

  return {
    items: page?.items ?? [],
    pageNumber: cursors.length,
    hasNext: Boolean(page?.nextCursor),
    hasPrevious: cursors.length > 1,
    next: () => page?.nextCursor && setCursors((c) => [...c, page.nextCursor]),
    previous: () => setCursors((c) => (c.length > 1 ? c.slice(0, -1) : c)),
    reload: useCallback(() => setReloadTick((n) => n + 1), []),
    error,
    isLoading,
  };
}

export function Pager({
  pageNumber,
  hasNext,
  hasPrevious,
  onNext,
  onPrevious,
  disabled,
}: {
  pageNumber: number;
  hasNext: boolean;
  hasPrevious: boolean;
  onNext: () => void;
  onPrevious: () => void;
  disabled?: boolean;
}) {
  if (!hasNext && !hasPrevious) return null;
  return (
    <div className="pager">
      <button className="btn" onClick={onPrevious} disabled={disabled || !hasPrevious}>
        ← Previous
      </button>
      <span className="muted">Page {pageNumber}</span>
      <button className="btn" onClick={onNext} disabled={disabled || !hasNext}>
        Next →
      </button>
    </div>
  );
}
