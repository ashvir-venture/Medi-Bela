'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { ApiError, Notice, listNotices } from '@/lib/api-client';
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

  const tabs: [Filter, string][] = [
    ['ALL', 'All'],
    ['PENDING_APPROVAL', 'Waiting for approval'],
    ['DRAFT', 'Drafts'],
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
            : 'Draft a notice and submit it; an admin approves it before users see it.'}
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
              {label} ({counts[key] ?? 0})
            </button>
          ))}
        </div>

        {error && <div className="error-banner">{error}</div>}

        {isLoading ? (
          <p className="muted">Loading…</p>
        ) : visible.length === 0 ? (
          <div className="empty-state">No notices here.</div>
        ) : (
          visible.map((n) => {
            const st = statusOf(n);
            const area = n.divisions.length ? n.divisions.map((d) => d.division.name).join(', ') : 'Whole country';
            return (
              <Link key={n.id} href={`${basePath}/${n.id}`} className="list-item">
                <div>
                  <div style={{ fontWeight: 600 }}>{n.title}</div>
                  <div className="muted">
                    {AUDIENCE_LABEL[n.audience]} · {area}
                    {n.source ? ` · ${n.source}` : ''}
                    {n.createdBy ? ` · by ${n.createdBy.name}` : ''}
                  </div>
                  {n.reviewNote && n.status === 'DRAFT' && (
                    <div className="line-warning">Sent back: {n.reviewNote}</div>
                  )}
                </div>
                <span className={`badge ${st.badge}`}>{st.label}</span>
              </Link>
            );
          })
        )}
      </div>
    </>
  );
}
