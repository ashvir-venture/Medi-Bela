'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ApiError, DashboardData, getDashboard } from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';
import { DataList } from '@/components/data-list';
import { StatusBadge } from '@/components/status-badge';
import { AnalyticsSection } from '@/components/analytics';

/**
 * Renders GET /admin/dashboard. No business logic here: every count,
 * percentage and trend is computed by the backend.
 */
export default function DashboardPage() {
  const ready = useRequireAuth();
  const [data, setData] = useState<DashboardData | null>(null);
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
      setData(await getDashboard());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load dashboard');
    } finally {
      setIsLoading(false);
    }
  }

  if (!ready) return null;

  return (
    <>
      <Topbar title="Dashboard" />
      <div className="page">
        {error && (
          <div className="error-banner">
            {error}{' '}
            <button className="btn" onClick={load} style={{ marginLeft: 8 }}>
              Retry
            </button>
          </div>
        )}

        {isLoading && !data ? (
          <p className="muted">Loading…</p>
        ) : !data ? null : (
          <>
            <div className="stat-grid">
              <div className="stat-card">
                <div className="stat-value">{data.totals.users}</div>
                <div className="muted">Total users</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{data.totals.families}</div>
                <div className="muted">Total families</div>
              </div>
              {/* Not a link: prescriptions are the pharmacists' work (no admin list). */}
              <div className={`stat-card ${data.totals.prescriptions.pending > 0 ? 'warn' : ''}`}>
                <div className="stat-value">{data.totals.prescriptions.pending}</div>
                <div className="muted">Pending prescriptions</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{data.totals.prescriptions.completed}</div>
                <div className="muted">Completed prescriptions</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{data.totals.prescriptions.rejected}</div>
                <div className="muted">Rejected prescriptions</div>
              </div>
            </div>

            <div className="card">
              <h2>Recently uploaded prescriptions</h2>
              {data.recentPrescriptions.length === 0 ? (
                <p className="muted">No prescriptions have been uploaded yet.</p>
              ) : (
                <DataList
                  rows={data.recentPrescriptions}
                  rowKey={(p) => p.id}
                  minWidth={420}
                  columns={[
                    { label: 'Patient', width: '1.5fr', render: (p) => <strong>{p.user.name}</strong> },
                    { label: 'Uploaded', width: '1.5fr', render: (p) => new Date(p.createdAt).toLocaleString() },
                    { label: 'Status', width: '1fr', end: true, render: (p) => <StatusBadge status={p.status} /> },
                  ]}
                />
              )}
            </div>

            <h3 className="section-title">Basic analytics</h3>
            <div className="stat-grid">
              <div className="stat-card">
                <div className="stat-value">
                  {data.analytics.doses7d.adherencePercent === null
                    ? '—'
                    : `${data.analytics.doses7d.adherencePercent}%`}
                </div>
                <div className="muted">
                  Dose adherence, last 7 days
                  {data.analytics.doses7d.adherencePercent === null
                    ? ' (no data yet)'
                    : ` (${data.analytics.doses7d.taken} taken, ${data.analytics.doses7d.missed} missed)`}
                </div>
              </div>
              <Link href="/super-control-007/notices" className="stat-card">
                <div className="stat-value">{data.analytics.liveNotices}</div>
                <div className="muted">Live notices</div>
              </Link>
              {/* Health rules and AI suggestions are managed by pharmacists. */}
              <div className="stat-card">
                <div className="stat-value">{data.analytics.activeRules}</div>
                <div className="muted">Active health rules</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{data.analytics.aiSuggestionsAwaitingReview}</div>
                <div className="muted">AI suggestions awaiting pharmacist review</div>
              </div>
            </div>

            <div className="card">
              <h2>Prescriptions uploaded per day (14 days)</h2>
              <Bars series={data.analytics.prescriptionsPerDay} />
            </div>
            <div className="card">
              <h2>New users per day (14 days)</h2>
              <Bars series={data.analytics.newUsersPerDay} />
            </div>

            <AnalyticsSection />

            <p className="muted" style={{ fontSize: 12 }}>
              Updated {new Date(data.generatedAt).toLocaleTimeString()} ·{' '}
              <button className="btn" onClick={load} disabled={isLoading}>
                {isLoading ? 'Refreshing…' : 'Refresh'}
              </button>
            </p>
          </>
        )}
      </div>
    </>
  );
}

function Bars({ series }: { series: { date: string; count: number }[] }) {
  const max = Math.max(1, ...series.map((d) => d.count));
  const total = series.reduce((sum, d) => sum + d.count, 0);
  if (total === 0) return <p className="muted">Nothing in this period yet.</p>;
  return (
    <>
      <div className="bars">
        {series.map((d) => (
          <div key={d.date} className="bar-col" title={`${d.date}: ${d.count}`}>
            <div
              className={`bar ${d.count === 0 ? 'zero' : ''}`}
              style={{ height: `${(d.count / max) * 100}%` }}
            />
          </div>
        ))}
      </div>
      <div className="bar-labels">
        <span>{series[0].date.slice(5)}</span>
        <span>{total} total</span>
        <span>{series[series.length - 1].date.slice(5)}</span>
      </div>
    </>
  );
}
