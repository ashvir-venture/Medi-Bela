'use client';

import { useState } from 'react';
import Link from 'next/link';
import { QueueStatus, listPrescriptionQueue } from '@/lib/api-client';
import { DataList } from '@/components/data-list';
import { Topbar } from '@/components/topbar';
import { StatusBadge } from '@/components/status-badge';
import { Pager, useCursorPager } from '@/components/pager';
import { Skeleton } from '@/components/skeleton';
import { EmptyState } from '@/components/empty-state';

const TABS: [QueueStatus, string][] = [
  ['PENDING', 'To review'],
  ['AWAITING_CONFIRMATION', 'Awaiting patient'],
  ['REJECTED', 'Rejected'],
  ['ACTIVE', 'Active'],
  ['ALL', 'All'],
];

const EMPTY: Record<QueueStatus, string> = {
  PENDING: 'Queue is clear',
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
          <Skeleton kind="table" />
        ) : pager.items.length === 0 ? (
          <EmptyState icon={status === 'PENDING' ? 'check' : 'prescription'} message={EMPTY[status]} />
        ) : (
          <DataList
            rows={pager.items}
            rowKey={(p) => p.id}
            rowHref={(p) => `${basePath}/${p.id}`}
            columns={[
              {
                label: 'Patient',
                width: '1.6fr',
                render: (p) => (
                  <strong>
                    {p.user.name}
                    {p.previousPrescriptionId && <span className="badge badge-draft tag">Re-upload</span>}
                  </strong>
                ),
              },
              { label: 'Uploaded', width: '1.4fr', render: (p) => new Date(p.createdAt).toLocaleString() },
              { label: 'Reviewed by', width: '1fr', render: (p) => p.reviewedBy?.name ?? '—' },
              { label: 'Status', width: '1.2fr', end: true, render: (p) => <StatusBadge status={p.status} /> },
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
