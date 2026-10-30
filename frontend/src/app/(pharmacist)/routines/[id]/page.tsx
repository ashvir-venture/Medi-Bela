'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import {
  ApiError,
  RoutineDetail,
  RoutineSuggestion,
  SuggestionItem,
  getRoutine,
  publishHealthSuggestion,
  requestRoutineSuggestion,
  unpublishHealthSuggestion,
} from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { PatientName } from '@/components/patient-name';
import { Topbar } from '@/components/topbar';
import { Skeleton } from '@/components/skeleton';
import { useToast } from '@/components/toast';
import { ErrorBanner } from '@/components/error-banner';

function Items({ label, items }: { label: string; items: SuggestionItem[] }) {
  return (
    <div style={{ marginTop: 12 }}>
      <div className="muted">{label}</div>
      {items.length === 0 ? (
        <p className="muted">No items.</p>
      ) : (
        <ul style={{ margin: '4px 0 0 18px' }}>
          {items.map((it, i) => (
            <li key={i}>
              <strong>{it.category}:</strong> {it.text}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

const fmt = (iso: string) => new Date(iso).toLocaleDateString();

/**
 * One routine + its AI suggestions. The suggestion is only ever created when
 * the pharmacist clicks "Request", and is only visible to the patient after an
 * explicit "Publish".
 */
export default function RoutineDetailPage() {
  const ready = useRequireAuth();
  const router = useRouter();
  const { id } = useParams<{ id: string }>();

  const [routine, setRoutine] = useState<RoutineDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();
  const [isLoading, setIsLoading] = useState(true);
  const [busy, setBusy] = useState<null | 'request' | string>(null);

  useEffect(() => {
    if (!ready) return;
    load();
  }, [ready, id]);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setRoutine(await getRoutine(id));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load routine');
    } finally {
      setIsLoading(false);
    }
  }

  async function run(key: string, action: () => Promise<unknown>, failMsg: string) {
    setBusy(key);
    setError(null);
    try {
      await action();
      setRoutine(await getRoutine(id));
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : failMsg);
    } finally {
      setBusy(null);
    }
  }

  if (!ready) return null;
  if (isLoading) {
    return (
      <>
        <Topbar title="Routine" />
        <div className="page">
          <Skeleton kind="detail" />
        </div>
      </>
    );
  }
  if (!routine) {
    return (
      <>
        <Topbar title="Routine" />
        <div className="page">{error && <ErrorBanner message={error} onRetry={load} />}</div>
      </>
    );
  }

  const hasDraft = routine.healthSuggestions.some((s) => s.status === 'DRAFT');

  return (
    <>
      <Topbar title={`Routine — ${routine.medicineName}`} />
      <div className="page">
        <button className="btn" style={{ marginBottom: 16 }} onClick={() => router.push('/routines')}>
          ← Back
        </button>

        {error && <div className="error-banner">{error}</div>}

        <div className="card">
          <h2>
            {routine.medicineName} <span className="muted">{routine.dosage}</span>
          </h2>
          <div>
            <PatientName user={routine.user} />
          </div>
          <div className="muted" style={{ marginTop: 8 }}>
            {routine.frequency} · from {fmt(routine.startDate)}
            {routine.endDate ? ` to ${fmt(routine.endDate)}` : ''} · {routine.active ? 'Active' : 'Inactive'}
          </div>
          {routine.prescriptionMedicine?.instructions && (
            <div className="muted" style={{ marginTop: 8 }}>
              Instructions: {routine.prescriptionMedicine.instructions}
            </div>
          )}
        </div>

        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
            <div>
              <h2 style={{ margin: 0 }}>AI health suggestion</h2>
              <div className="muted">
                Only this medicine&apos;s name and dosage are sent to the AI. Nothing is shown to the patient until you publish.
              </div>
            </div>
            <button
              className="btn btn-primary"
              disabled={busy !== null}
              onClick={() => run('request', () => requestRoutineSuggestion(id), 'Failed to get a suggestion')}
            >
              {busy === 'request' ? 'Asking AI…' : hasDraft ? 'Regenerate draft' : 'Request AI suggestion'}
            </button>
          </div>
        </div>

        {routine.healthSuggestions.length === 0 && <p className="muted">No suggestion requested for this routine yet.</p>}

        {routine.healthSuggestions.map((s: RoutineSuggestion) => (
          <div key={s.id} className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <span className={`badge ${s.status === 'PUBLISHED' ? 'badge-completed' : 'badge-draft'}`}>
                  {s.status === 'PUBLISHED' ? 'Published' : 'Draft (not visible to patient)'}
                </span>
                <span className="muted" style={{ marginLeft: 8 }}>
                  {fmt(s.createdAt)}
                  {s.publishedBy ? ` · published by ${s.publishedBy.name}` : ''}
                </span>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <Link href={`/health-suggestions/${s.id}`} className="btn">
                  Review &amp; edit
                </Link>
                {s.status === 'PUBLISHED' ? (
                  <button
                    className="btn"
                    disabled={busy !== null}
                    onClick={() => run(s.id, () => unpublishHealthSuggestion(s.id), 'Failed to unpublish')}
                  >
                    {busy === s.id ? '…' : 'Unpublish'}
                  </button>
                ) : (
                  <button
                    className="btn btn-primary"
                    disabled={busy !== null}
                    onClick={() => run(s.id, () => publishHealthSuggestion(s.id), 'Failed to publish')}
                  >
                    {busy === s.id ? '…' : 'Publish'}
                  </button>
                )}
              </div>
            </div>
            <Items label="English" items={s.itemsEn} />
            <Items label="বাংলা (Bengali)" items={s.itemsBn} />
          </div>
        ))}
      </div>
    </>
  );
}
