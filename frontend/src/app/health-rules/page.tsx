'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ApiError, SuggestionRule, listSuggestionRules } from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

export default function HealthRulesPage() {
  const ready = useRequireAuth();
  const [rules, setRules] = useState<SuggestionRule[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [filter, setFilter] = useState<'ALL' | 'ACTIVE' | 'INACTIVE'>('ALL');

  useEffect(() => {
    if (!ready) return;
    load();
  }, [ready]);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setRules(await listSuggestionRules());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load rules');
    } finally {
      setIsLoading(false);
    }
  }

  if (!ready) return null;

  const activeCount = rules.filter((r) => r.enabled).length;
  const visible = rules.filter((r) =>
    filter === 'ALL' ? true : filter === 'ACTIVE' ? r.enabled : !r.enabled,
  );

  return (
    <>
      <Topbar title="Health Suggestion Rules" />
      <div className="page">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <p className="muted" style={{ margin: 0 }}>
            A rule only creates reminders for users while it is Active. New rules start Inactive until you activate them.
          </p>
          <Link href="/health-rules/new" className="btn btn-primary">
            + New rule
          </Link>
        </div>

        <div className="tabs">
          {([
            ['ALL', `All (${rules.length})`],
            ['ACTIVE', `Active (${activeCount})`],
            ['INACTIVE', `Inactive (${rules.length - activeCount})`],
          ] as const).map(([key, label]) => (
            <button
              key={key}
              className={`tab ${filter === key ? 'active' : ''}`}
              onClick={() => setFilter(key)}
            >
              {label}
            </button>
          ))}
        </div>

        {error && (
          <div className="error-banner">
            {error}{' '}
            <button className="btn" onClick={load} style={{ marginLeft: 8 }}>
              Retry
            </button>
          </div>
        )}

        {isLoading ? (
          <p className="muted">Loading…</p>
        ) : rules.length === 0 ? (
          <p className="muted">No rules yet. Create one to get started.</p>
        ) : visible.length === 0 ? (
          <p className="muted">No {filter === 'ACTIVE' ? 'active' : 'inactive'} rules.</p>
        ) : (
          visible.map((rule) => (
            <Link key={rule.id} href={`/health-rules/${rule.id}`} className="list-item">
              <div>
                <div style={{ fontWeight: 600 }}>{rule.name}</div>
                <div className="muted">
                  IF medicine name contains{' '}
                  &ldquo;{rule.conditionValue}&rdquo; → health reminder: &ldquo;{rule.suggestedAction}&rdquo;
                </div>
              </div>
              <span className={`badge ${rule.enabled ? 'badge-completed' : 'badge-draft'}`}>
                {rule.enabled ? 'Active' : 'Inactive'}
              </span>
            </Link>
          ))
        )}
      </div>
    </>
  );
}
