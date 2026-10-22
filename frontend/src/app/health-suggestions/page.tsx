'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ApiError, HealthSuggestion, listHealthSuggestions } from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

/**
 * One row per AI suggestion an admin requested for a routine.
 * Nothing here is visible to the user until it's opened and published.
 */
export default function HealthSuggestionsPage() {
  const ready = useRequireAuth();
  const [suggestions, setSuggestions] = useState<HealthSuggestion[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!ready) return;
    load();
  }, [ready]);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setSuggestions(await listHealthSuggestions());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load suggestions');
    } finally {
      setIsLoading(false);
    }
  }

  if (!ready) return null;

  return (
    <>
      <Topbar title="AI Health Suggestions" />
      <div className="page">
        <p className="muted" style={{ marginBottom: 16 }}>
          Requested by an admin from the Routines panel (never automatic). Review, edit if
          needed, then Publish before a user can see it.
        </p>

        {error && <div className="error-banner">{error}</div>}

        {isLoading ? (
          <p className="muted">Loading…</p>
        ) : suggestions.length === 0 ? (
          <p className="muted">No AI suggestions generated yet.</p>
        ) : (
          suggestions.map((s) => (
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
      </div>
    </>
  );
}
