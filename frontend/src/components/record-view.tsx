'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ApiError } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';

/**
 * Read-only record page for the admin area: label / value rows, with
 * missing values shown as "Not set". Used by doctor and medicine detail.
 */
export function RecordView<T>({
  recordId,
  load,
  title,
  backHref,
  backLabel,
  rows,
  incomplete,
}: {
  recordId: string;
  load: () => Promise<T>;
  title: (record: T) => string;
  backHref: string;
  backLabel: string;
  rows: (record: T) => [label: string, value: React.ReactNode][];
  incomplete: (record: T) => boolean;
}) {
  const [record, setRecord] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    load()
      .then(setRecord)
      .catch((err) => setError(err instanceof ApiError ? err.message : 'Failed to load'));
    // load is recreated each render; reload only when the record changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recordId]);

  return (
    <>
      <Topbar
        title={record ? title(record) : 'Loading…'}
        actions={
          <Link href={backHref} className="btn">
            ← {backLabel}
          </Link>
        }
      />
      <div className="page">
        {error && <div className="error-banner">{error}</div>}
        {!record ? (
          !error && <p className="muted">Loading…</p>
        ) : (
          <div className="card">
            <div className="card-head" style={{ marginBottom: 12 }}>
              {incomplete(record) ? (
                <span className="badge badge-pending">Incomplete</span>
              ) : (
                <span className="badge badge-completed">Complete</span>
              )}
              <span className="muted">Read-only. Pharmacists edit these records.</span>
            </div>
            <dl className="record-grid">
              {rows(record).map(([label, value]) => (
                <div key={label}>
                  <dt>{label}</dt>
                  <dd>{value === null || value === undefined || value === '' ? <span className="muted">Not set</span> : value}</dd>
                </div>
              ))}
            </dl>
          </div>
        )}
      </div>
    </>
  );
}
