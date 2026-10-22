'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { ApiError, RoutineListItem, listRoutines } from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

type Filter = 'active' | 'all';

/**
 * Every routine generated from a verified prescription, with the status of
 * its AI suggestion. Suggestions are never created automatically: open a
 * routine and request one.
 */
export default function RoutinesPage() {
  const ready = useRequireAuth();
  const [routines, setRoutines] = useState<RoutineListItem[]>([]);
  const [filter, setFilter] = useState<Filter>('active');
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!ready) return;
    load();
  }, [ready, filter]);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setRoutines(await listRoutines(filter === 'active' ? { active: true } : {}));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load routines');
    } finally {
      setIsLoading(false);
    }
  }

  const visible = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return routines;
    return routines.filter(
      (r) =>
        r.medicineName.toLowerCase().includes(q) ||
        r.user.name.toLowerCase().includes(q) ||
        r.user.phone.includes(q),
    );
  }, [routines, search]);

  if (!ready) return null;

  return (
    <>
      <Topbar title="Routines" />
      <div className="page">
        <p className="muted" style={{ marginBottom: 16 }}>
          Routines created from verified prescriptions. Open one to request an AI health
          suggestion for it; nothing is generated or shown to users until you publish it.
        </p>

        <div className="row" style={{ marginBottom: 16, alignItems: 'flex-end' }}>
          <div className="field">
            <label>Search (medicine, patient name or phone)</label>
            <input className="input" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <div className="field" style={{ flex: '0 0 160px' }}>
            <label>Show</label>
            <select className="input" value={filter} onChange={(e) => setFilter(e.target.value as Filter)}>
              <option value="active">Active routines</option>
              <option value="all">All routines</option>
            </select>
          </div>
        </div>

        {error && <div className="error-banner">{error}</div>}

        {isLoading ? (
          <p className="muted">Loading…</p>
        ) : visible.length === 0 ? (
          <p className="muted">No routines found.</p>
        ) : (
          visible.map((r) => {
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
      </div>
    </>
  );
}
