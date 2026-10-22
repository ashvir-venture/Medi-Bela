'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ApiError, Notice, listNotices } from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

const STATUS_BADGE: Record<Notice['status'], string> = {
  DRAFT: 'badge-draft',
  PUBLISHED: 'badge-completed',
  ARCHIVED: 'badge-rejected',
};

const AUDIENCE_LABEL: Record<Notice['audience'], string> = {
  ALL: 'Everyone',
  USER: 'Patients only',
  ADMIN: 'Admins/pharmacists only',
};

function isExpired(expiresAt: string | null) {
  return expiresAt !== null && new Date(expiresAt).getTime() <= Date.now();
}

export default function NoticesPage() {
  const ready = useRequireAuth();
  const [notices, setNotices] = useState<Notice[]>([]);
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
      setNotices(await listNotices());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load notices');
    } finally {
      setIsLoading(false);
    }
  }

  if (!ready) return null;

  return (
    <>
      <Topbar title="Government Notices" />
      <div className="page">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <p className="muted" style={{ margin: 0 }}>
            A notice only appears to users after you Publish it.
          </p>
          <Link href="/notices/new" className="btn btn-primary">
            + New notice
          </Link>
        </div>

        {error && <div className="error-banner">{error}</div>}

        {isLoading ? (
          <p className="muted">Loading…</p>
        ) : notices.length === 0 ? (
          <p className="muted">No notices yet.</p>
        ) : (
          notices.map((n) => (
            <Link key={n.id} href={`/notices/${n.id}`} className="list-item">
              <div>
                <div style={{ fontWeight: 600 }}>{n.title}</div>
                <div className="muted">
                  Audience: {AUDIENCE_LABEL[n.audience]}
                  {n.expiresAt ? ` • expires ${new Date(n.expiresAt).toLocaleString()}` : ' • no expiry'}
                </div>
              </div>
              {/* A published notice past its expiry is NOT live: show that clearly. */}
              {n.status === 'PUBLISHED' && isExpired(n.expiresAt) ? (
                <span className="badge badge-expired">EXPIRED</span>
              ) : (
                <span className={`badge ${STATUS_BADGE[n.status]}`}>{n.status}</span>
              )}
            </Link>
          ))
        )}
      </div>
    </>
  );
}
