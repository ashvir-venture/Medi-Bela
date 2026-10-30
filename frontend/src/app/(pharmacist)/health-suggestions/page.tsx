'use client';

import { Suspense, useEffect, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { HealthSuggestion, listHealthSuggestions } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { Pager, useCursorPager } from '@/components/pager';

type Filter = '' | HealthSuggestion['status'];

/**
 * One row per AI suggestion a pharmacist requested for a routine, 20 per
 * page. Nothing here is visible to the patient until it's opened and
 * published. The dashboard opens it with ?status=DRAFT.
 */
export default function HealthSuggestionsPage() {
  return (
    // useSearchParams needs a Suspense boundary in the App Router.
    <Suspense>
      <SuggestionList />
    </Suspense>
  );
}

function SuggestionList() {
  const searchParams = useSearchParams();
  const initial = searchParams.get('status');
  const [status, setStatus] = useState<Filter>(initial === 'DRAFT' || initial === 'PUBLISHED' ? initial : '');
  const [q, setQ] = useState('');
  const [debouncedQ, setDebouncedQ] = useState('');

  useEffect(() => {
    const t = setTimeout(() => setDebouncedQ(q.trim()), 300);
    return () => clearTimeout(t);
  }, [q]);

  const pager = useCursorPager(
    (cursor) => listHealthSuggestions({ cursor, q: debouncedQ || undefined, status: status || undefined }),
    `${debouncedQ}|${status}`,
  );

  return (
    <>
      <Topbar title="AI Health Suggestions" />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          Requested from the Routines panel (never automatic). Review, edit if needed, then
          Publish before a patient can see it.
        </p>

        <div className="filter-bar">
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="suggestion-search">Search (medicine, patient name or phone)</label>
            <input id="suggestion-search" className="input" value={q} onChange={(e) => setQ(e.target.value)} />
          </div>
          <div className="field" style={{ marginBottom: 0, flex: '0 0 180px' }}>
            <label htmlFor="suggestion-status">Status</label>
            <select
              id="suggestion-status"
              className="input"
              value={status}
              onChange={(e) => setStatus(e.target.value as Filter)}
            >
              <option value="">All</option>
              <option value="DRAFT">Drafts</option>
              <option value="PUBLISHED">Published</option>
            </select>
          </div>
        </div>

        {pager.error && <div className="error-banner">{pager.error}</div>}

        {pager.isLoading && pager.items.length === 0 ? (
          <p className="muted">Loading…</p>
        ) : pager.items.length === 0 ? (
          <div className="empty-state">No AI suggestions found.</div>
        ) : (
          pager.items.map((s) => (
            <Link key={s.id} href={`/health-suggestions/${s.id}`} className="list-item">
              <div>
                <div style={{ fontWeight: 600 }}>{s.user.name}</div>
                <div className="muted">Routine: {s.sourceMedicines}</div>
              </div>
              <span className={`badge ${s.status === 'PUBLISHED' ? 'badge-completed' : 'badge-draft'}`}>
                {s.status === 'PUBLISHED' ? 'Published' : 'Draft'}
              </span>
            </Link>
          ))
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
