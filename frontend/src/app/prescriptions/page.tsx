'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ApiError, PrescriptionListItem, listPendingPrescriptions } from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

export default function PendingPrescriptionsPage() {
  const ready = useRequireAuth();
  const [prescriptions, setPrescriptions] = useState<PrescriptionListItem[]>([]);
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
      const data = await listPendingPrescriptions();
      setPrescriptions(data);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load prescriptions');
    } finally {
      setIsLoading(false);
    }
  }

  if (!ready) return null;

  return (
    <>
      <Topbar title="Pending Prescriptions" />
      <div className="page">
        {error && <div className="error-banner">{error}</div>}
        {isLoading ? (
          <p className="muted">Loading…</p>
        ) : prescriptions.length === 0 ? (
          <p className="muted">No prescriptions are waiting for review right now.</p>
        ) : (
          prescriptions.map((p) => (
            <Link key={p.id} href={`/prescriptions/${p.id}`} className="list-item">
              <div>
                <div style={{ fontWeight: 600 }}>{p.user.name}</div>
                <div className="muted">
                  {p.user.phone} • uploaded {new Date(p.createdAt).toLocaleString()}
                </div>
              </div>
              <span className="btn btn-primary">Review</span>
            </Link>
          ))
        )}
      </div>
    </>
  );
}
