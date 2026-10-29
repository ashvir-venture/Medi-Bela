'use client';

import { useState } from 'react';
import Link from 'next/link';
import { QueueStatus, listPrescriptionQueue } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { StatusBadge } from '@/components/status-badge';
import { Pager, useCursorPager } from '@/components/pager';

const TABS: [QueueStatus, string][] = [
  ['PENDING', 'To review'],
  ['AWAITING_CONFIRMATION', 'Awaiting patient'],
  ['REJECTED', 'Rejected'],
  ['ACTIVE', 'Active'],
  ['ALL', 'All'],
];

const EMPTY: Record<QueueStatus, string> = {
  PENDING: 'Nothing to review right now.',
  AWAITING_CONFIRMATION: 'No prescriptions are waiting for a patient.',
  REJECTED: 'No rejected prescriptions.',
  ACTIVE: 'No active prescriptions.',
  ENDED: 'No ended prescriptions.',
  ALL: 'No prescriptions yet.',
};

/** Prescription queue, 20 per page, newest first. Shared by both areas. */
export function PrescriptionQueue({ basePath, intro }: { basePath: string; intro: string }) {
  const [status, setStatus] = useState<QueueStatus>('PENDING');
  const pager = useCursorPager((cursor) => listPrescriptionQueue(status, cursor), status);

  return (
    <>
      <Topbar title="Prescriptions" />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          {intro}
        </p>

        <div className="tabs" role="tablist">
          {TABS.map(([key, label]) => (
            <button
              key={key}
              role="tab"
              aria-selected={status === key}
              className={`tab ${status === key ? 'active' : ''}`}
              onClick={() => setStatus(key)}
            >
              {label}
            </button>
          ))}
        </div>

        {pager.error && (
          <div className="error-banner">
            {pager.error}{' '}
            <button className="btn btn-sm" onClick={pager.reload}>
              Retry
            </button>
          </div>
        )}

        {pager.isLoading && pager.items.length === 0 ? (
          <p className="muted">Loading…</p>
        ) : pager.items.length === 0 ? (
          <div className="empty-state">{EMPTY[status]}</div>
        ) : (
          pager.items.map((p) => (
            <Link key={p.id} href={`${basePath}/${p.id}`} className="list-item">
              <div>
                <div style={{ fontWeight: 600 }}>
                  {p.user.name}
                  {p.previousPrescriptionId && <span className="badge badge-draft tag">Re-upload</span>}
                </div>
                <div className="muted">
                  Uploaded {new Date(p.createdAt).toLocaleString()}
                  {p.reviewedBy ? ` · by ${p.reviewedBy.name}` : ''}
                </div>
              </div>
              <StatusBadge status={p.status} />
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
