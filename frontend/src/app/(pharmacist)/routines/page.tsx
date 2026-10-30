'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { listRoutines } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { Pager, useCursorPager } from '@/components/pager';

type Filter = 'active' | 'all';

/**
 * Every routine generated from a verified prescription, with the status of
 * its AI suggestion, 20 per page. Suggestions are never created
 * automatically: open a routine and request one.
 */
export default function RoutinesPage() {
  const [filter, setFilter] = useState<Filter>('active');
  const [q, setQ] = useState('');
  const [debouncedQ, setDebouncedQ] = useState('');

  useEffect(() => {
    const t = setTimeout(() => setDebouncedQ(q.trim()), 300);
    return () => clearTimeout(t);
  }, [q]);

  const pager = useCursorPager(
    (cursor) => listRoutines({ cursor, q: debouncedQ || undefined, active: filter === 'active' }),
    `${debouncedQ}|${filter}`,
  );

  return (
    <>
      <Topbar title="Routines" />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          Routines created from verified prescriptions. Open one to request an AI health
          suggestion for it; nothing is generated or shown to patients until you publish it.
        </p>

        <div className="filter-bar">
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="routine-search">Search (medicine, patient name or phone)</label>
            <input id="routine-search" className="input" value={q} onChange={(e) => setQ(e.target.value)} />
          </div>
          <div className="field" style={{ marginBottom: 0, flex: '0 0 180px' }}>
            <label htmlFor="routine-filter">Show</label>
            <select
              id="routine-filter"
              className="input"
              value={filter}
              onChange={(e) => setFilter(e.target.value as Filter)}
            >
              <option value="active">Active routines</option>
              <option value="all">All routines</option>
            </select>
          </div>
        </div>

        {pager.error && <div className="error-banner">{pager.error}</div>}

        {pager.isLoading && pager.items.length === 0 ? (
          <p className="muted">Loading…</p>
        ) : pager.items.length === 0 ? (
          <div className="empty-state">No routines found.</div>
        ) : (
          pager.items.map((r) => {
            const latest = r.healthSuggestions[0];
            return (
              <Link key={r.id} href={`/routines/${r.id}`} className="list-item">
                <div>
                  <div style={{ fontWeight: 600 }}>
                    {r.medicineName} <span className="muted">{r.dosage}</span>
                  </div>
                  <div className="muted">
                    {r.user.name} ({r.user.phone}) · {r.frequency}
                    {r.active ? '' : ' · inactive'}
                  </div>
                </div>
                <span
                  className={`badge ${
                    latest ? (latest.status === 'PUBLISHED' ? 'badge-completed' : 'badge-draft') : 'badge-pending'
                  }`}
                >
                  {latest ? (latest.status === 'PUBLISHED' ? 'Suggestion published' : 'Suggestion draft') : 'No suggestion'}
                </span>
              </Link>
            );
          })
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
