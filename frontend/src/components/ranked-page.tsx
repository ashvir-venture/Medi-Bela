'use client';

import Link from 'next/link';
import { CursorPage } from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { Topbar } from '@/components/topbar';
import { Pager, useCursorPager } from '@/components/pager';

/** A full ranking from the analytics (20 per page, Next / Previous). */
export function RankedPage<T extends { rank: number }>({
  title,
  intro,
  fetchPage,
  renderRows,
}: {
  title: string;
  intro: string;
  fetchPage: (cursor: string | null) => Promise<CursorPage<T>>;
  renderRows: (items: T[]) => React.ReactNode;
}) {
  const pager = useCursorPager(fetchPage, title);
  return (
    <>
      <Topbar
        title={title}
        actions={
          <Link href={`${ADMIN_BASE}/dashboard`} className="btn">
            ← Dashboard
          </Link>
        }
      />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          {intro}
        </p>
        {pager.error && <div className="error-banner">{pager.error}</div>}
        {pager.isLoading && pager.items.length === 0 ? <p className="muted">Loading…</p> : renderRows(pager.items)}
        <Pager
          pageNumber={pager.pageNumber}
          hasNext={pager.hasNext}
          hasPrevious={pager.hasPrevious}
          onNext={pager.next}
          onPrevious={pager.previous}
          disabled={pager.isLoading}
        />
      </div>
    </>
  );
}
