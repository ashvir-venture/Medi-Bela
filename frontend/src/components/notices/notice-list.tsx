'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { ApiError, Notice, listNotices } from '@/lib/api-client';
import { DataList } from '@/components/data-list';
import { Topbar } from '@/components/topbar';
import { NOTICE_STATUS, isScheduled } from '@/components/notices/notice-detail';

const AUDIENCE_LABEL: Record<Notice['audience'], string> = {
  ALL: 'Everyone',
  USER: 'Patients only',
  ADMIN: 'Admins/pharmacists only',
};

type Filter = 'ALL' | Notice['status'];

function isExpired(expiresAt: string | null) {
  return expiresAt !== null && new Date(expiresAt).getTime() <= Date.now();
}

function statusOf(n: Notice) {
  if (isScheduled(n)) return { label: 'Scheduled', badge: 'badge-pending' };
  // A published notice past its expiry is NOT live: show that clearly.
  if (n.status === 'PUBLISHED' && isExpired(n.expiresAt)) return { label: 'Expired', badge: 'badge-expired' };
  return NOTICE_STATUS[n.status];
}

/** Shared by both areas; links stay under [basePath]. Admins land on what waits for approval. */
export function NoticeList({ basePath, role }: { basePath: string; role: 'ADMIN' | 'PHARMACIST' }) {
  const [notices, setNotices] = useState<Notice[]>([]);
  const [filter, setFilter] = useState<Filter>('ALL');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const list = await listNotices();
      setNotices(list);
      if (role === 'ADMIN' && list.some((n) => n.status === 'PENDING_APPROVAL')) setFilter('PENDING_APPROVAL');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load notices');
    } finally {
      setIsLoading(false);
    }
  }

  const counts = useMemo(() => {
    const c: Record<string, number> = { ALL: notices.length };
    for (const n of notices) c[n.status] = (c[n.status] ?? 0) + 1;
    return c;
  }, [notices]);
  const visible = filter === 'ALL' ? notices : notices.filter((n) => n.status === filter);

  // Tabs follow the flow: drafting -> approval -> published (admins: their drafts publish directly).
  const tabs: [Filter, string][] =
    role === 'ADMIN'
      ? [
          ['ALL', 'All'],
          ['PENDING_APPROVAL', 'Waiting for approval'],
          ['DRAFT', 'Drafts'],
          ['PUBLISHED', 'Published'],
          ['ARCHIVED', 'Archived'],
        ]
      : [
          ['ALL', 'All'],
          ['DRAFT', 'My drafts'],
          ['PENDING_APPROVAL', 'Sent for approval'],
          ['PUBLISHED', 'Published'],
          ['ARCHIVED', 'Archived'],
        ];

  return (
    <>
      <Topbar
        title="Notices"
        actions={
          <Link href={`${basePath}/new`} className="btn btn-primary">
            + New notice
          </Link>
        }
      />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          {role === 'ADMIN'
            ? 'Your own notices publish directly. Pharmacists’ notices wait for your approval.'
            : 'Drafts stay with you until you submit them. An admin approves a submitted notice before users see it.'}
        </p>

        <div className="tabs" role="tablist">
          {tabs.map(([key, label]) => (
            <button
              key={key}
              role="tab"
              aria-selected={filter === key}
              className={`tab ${filter === key ? 'active' : ''}`}
              onClick={() => setFilter(key)}
            >
              {label} <span className="tab-count">{counts[key] ?? 0}</span>
            </button>
          ))}
        </div>

        {error && <div className="error-banner">{error}</div>}

        {isLoading ? (
          <p className="muted">Loading…</p>
        ) : visible.length === 0 ? (
          <div className="empty-state">No notices here.</div>
        ) : (
          <DataList<Notice>
            rows={visible}
            rowKey={(n) => n.id}
            rowHref={(n) => `${basePath}/${n.id}`}
            columns={[
              {
                label: 'Notice',
                width: '2.4fr',
                render: (n) => (
                  <>
                    <strong>{n.title}</strong>
                    {n.source && <div className="muted">{n.source}</div>}
                    {n.reviewNote && n.status === 'DRAFT' && (
                      <div className="line-warning">Sent back: {n.reviewNote}</div>
                    )}
                  </>
                ),
              },
              {
                label: 'Audience',
                width: '1.4fr',
                render: (n) => (
                  <>
                    {AUDIENCE_LABEL[n.audience]}
                    <div className="muted">
                      {n.divisions.length ? n.divisions.map((d) => d.division.name).join(', ') : 'Whole country'}
                    </div>
                  </>
                ),
              },
              { label: 'By', width: '1fr', render: (n) => n.createdBy?.name ?? '—' },
              {
                label: 'Status',
                width: '120px',
                end: true,
                render: (n) => {
                  const st = statusOf(n);
                  return <span className={`badge ${st.badge}`}>{st.label}</span>;
                },
              },
            ]}
          />
        )}
      </div>
    </>
  );
}
