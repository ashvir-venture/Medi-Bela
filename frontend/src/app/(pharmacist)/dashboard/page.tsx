'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ApiError, PharmacistDashboardData, getPharmacistDashboard } from '@/lib/api-client';
import { DataList } from '@/components/data-list';
import { Topbar } from '@/components/topbar';

/** The pharmacist's overview: what is waiting and what they finished today. */
export default function PharmacistDashboardPage() {
  const [data, setData] = useState<PharmacistDashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setData(await getPharmacistDashboard());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load dashboard');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <>
      <Topbar
        title="Dashboard"
        actions={
          <button className="btn" onClick={load} disabled={isLoading}>
            {isLoading ? 'Refreshing…' : 'Refresh'}
          </button>
        }
      />
      <div className="page">
        {error && (
          <div className="error-banner">
            {error}{' '}
            <button className="btn btn-sm" onClick={load}>
              Retry
            </button>
          </div>
        )}

        {isLoading && !data ? (
          <p className="muted">Loading…</p>
        ) : !data ? null : (
          <>
            <h3 className="section-title">Queue</h3>
            <div className="stat-grid">
              <Link href="/prescriptions" className={`stat-card ${data.queue.pending > 0 ? 'warn' : ''}`}>
                <div className="stat-value">{data.queue.pending}</div>
                <div className="muted">To review</div>
              </Link>
              <div className="stat-card">
                <div className="stat-value">{data.queue.reuploads}</div>
                <div className="muted">Re-uploads among them</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{data.queue.awaitingConfirmation}</div>
                <div className="muted">Waiting for the patient</div>
              </div>
            </div>

            <h3 className="section-title">Your work today</h3>
            <div className="stat-grid">
              <div className="stat-card">
                <div className="stat-value">{data.today.prepared}</div>
                <div className="muted">Sent for confirmation</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{data.today.rejected}</div>
                <div className="muted">Rejected with feedback</div>
              </div>
            </div>

            <h3 className="section-title">Records to complete</h3>
            <div className="stat-grid">
              <Link href="/doctors?incomplete=1" className="stat-card">
                <div className="stat-value">{data.catalog.incompleteDoctors}</div>
                <div className="muted">Doctors missing specialty, phone or chamber / address</div>
              </Link>
              <Link href="/medicines?incomplete=1" className="stat-card">
                <div className="stat-value">{data.catalog.incompleteMedicines}</div>
                <div className="muted">Medicines missing form, category or manufacturer</div>
              </Link>
              <Link
                href="/health-suggestions?status=DRAFT"
                className={`stat-card ${data.aiSuggestions.drafts > 0 ? 'warn' : ''}`}
              >
                <div className="stat-value">{data.aiSuggestions.drafts}</div>
                <div className="muted">AI suggestions awaiting review</div>
              </Link>
            </div>

            <div className="card">
              <h2>Waiting longest</h2>
              {data.oldestPending.length === 0 ? (
                <p className="muted">Nothing waiting. Good work.</p>
              ) : (
                <DataList
                  rows={data.oldestPending}
                  rowKey={(p) => p.id}
                  rowHref={(p) => `/prescriptions/${p.id}`}
                  minWidth={420}
                  columns={[
                    {
                      label: 'Patient',
                      width: '1.5fr',
                      render: (p) => (
                        <strong>
                          {p.user.name}
                          {p.previousPrescriptionId && <span className="badge badge-draft tag">Re-upload</span>}
                        </strong>
                      ),
                    },
                    { label: 'Uploaded', width: '1.5fr', render: (p) => new Date(p.createdAt).toLocaleString() },
                    { label: '', width: '90px', end: true, render: () => <span className="btn btn-primary btn-sm">Review</span> },
                  ]}
                />
              )}
            </div>
          </>
        )}
      </div>
    </>
  );
}
