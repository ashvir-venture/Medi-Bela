'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { CatalogListParams, CursorPage } from '@/lib/api-client';
import { DataList } from '@/components/data-list';
import { Topbar } from '@/components/topbar';
import { Pager, useCursorPager } from '@/components/pager';

/**
 * Doctors / medicines list: name prefix search, "incomplete only" filter
 * (opened from the dashboard with ?incomplete=1), 20 per page.
 */
export function CatalogList<T extends { id: string }>({
  title,
  intro,
  basePath,
  searchLabel,
  incompleteLabel,
  fetchPage,
  renderRow,
  isIncomplete,
}: {
  title: string;
  intro: string;
  basePath: string;
  searchLabel: string;
  incompleteLabel: string;
  fetchPage: (params: CatalogListParams) => Promise<CursorPage<T>>;
  renderRow: (item: T) => React.ReactNode;
  isIncomplete: (item: T) => boolean;
}) {
  const searchParams = useSearchParams();
  const [incomplete, setIncomplete] = useState(searchParams.get('incomplete') === '1');
  const [q, setQ] = useState('');
  const [debouncedQ, setDebouncedQ] = useState('');

  useEffect(() => {
    const t = setTimeout(() => setDebouncedQ(q.trim()), 300);
    return () => clearTimeout(t);
  }, [q]);

  const pager = useCursorPager(
    (cursor) => fetchPage({ cursor, q: debouncedQ || undefined, incomplete }),
    `${debouncedQ}|${incomplete}`,
  );

  return (
    <>
      <Topbar title={title} />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          {intro}
        </p>
        <div className="filter-bar">
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="catalog-search">{searchLabel}</label>
            <input id="catalog-search" className="input" value={q} onChange={(e) => setQ(e.target.value)} />
          </div>
          <label className="checkbox">
            <input type="checkbox" checked={incomplete} onChange={(e) => setIncomplete(e.target.checked)} />
            {incompleteLabel}
          </label>
        </div>

        {pager.error && <div className="error-banner">{pager.error}</div>}

        {pager.isLoading && pager.items.length === 0 ? (
          <p className="muted">Loading…</p>
        ) : pager.items.length === 0 ? (
          <div className="empty-state">Nothing found.</div>
        ) : (
          <DataList<T>
            rows={pager.items}
            rowKey={(item) => item.id}
            rowHref={(item) => `${basePath}/${item.id}`}
            minWidth={480}
            columns={[
              { label: 'Record', width: '4fr', render: renderRow },
              {
                label: 'Status',
                width: '130px',
                end: true,
                render: (item) =>
                  isIncomplete(item) ? (
                    <span className="badge badge-pending">Incomplete</span>
                  ) : (
                    <span className="badge badge-completed">Complete</span>
                  ),
              },
            ]}
          />
        )}

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
