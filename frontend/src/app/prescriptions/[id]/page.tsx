'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  ApiError,
  PrescriptionDetail,
  completePrescription,
  getPrescription,
  rejectPrescription,
  removeMedicine,
  saveMedicines,
} from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';
import { StatusBadge } from '@/components/status-badge';
import {
  MedicineFormRow,
  MedicineRowEditor,
  emptyRow,
  medicineToRow,
  rowToEntry,
} from '@/components/medicine-form';

let tmpRowCounter = 0;

export default function PrescriptionDetailPage() {
  const ready = useRequireAuth();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params.id;

  const [prescription, setPrescription] = useState<PrescriptionDetail | null>(null);
  const [rows, setRows] = useState<MedicineFormRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);

  useEffect(() => {
    if (!ready) return;
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, id]);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const data = await getPrescription(id);
      setPrescription(data);
      setRows(data.medicines.map(medicineToRow));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load prescription');
    } finally {
      setIsLoading(false);
    }
  }

  const isPending = prescription?.status === 'PENDING';

  function updateRow(index: number, next: MedicineFormRow) {
    setRows((prev) => prev.map((r, i) => (i === index ? next : r)));
  }

  function addRow() {
    setRows((prev) => [...prev, emptyRow(`tmp-${tmpRowCounter++}`)]);
  }

  async function removeRow(index: number) {
    const row = rows[index];
    if (row.id) {
      setIsSaving(true);
      setError(null);
      try {
        const updated = await removeMedicine(id, row.id);
        setPrescription(updated);
        setRows(updated.medicines.map(medicineToRow));
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'Failed to remove medicine');
      } finally {
        setIsSaving(false);
      }
      return;
    }
    setRows((prev) => prev.filter((_, i) => i !== index));
  }

  async function handleSaveMedicines() {
    setIsSaving(true);
    setError(null);
    try {
      const entries = rows
        .filter((r) => r.medicineName.trim() && r.dosage.trim() && r.frequency.trim() && r.duration.trim())
        .map(rowToEntry);
      const updated = await saveMedicines(id, entries);
      setPrescription(updated);
      setRows(updated.medicines.map(medicineToRow));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to save medicines');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleComplete() {
    setIsSaving(true);
    setError(null);
    try {
      // Persist any unsaved edits first so completion validates against
      // the latest schedule data the pharmacist just entered.
      const entries = rows
        .filter((r) => r.medicineName.trim() && r.dosage.trim() && r.frequency.trim() && r.duration.trim())
        .map(rowToEntry);
      await saveMedicines(id, entries);
      const updated = await completePrescription(id);
      setPrescription(updated);
      setRows(updated.medicines.map(medicineToRow));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to complete prescription');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleReject() {
    if (!rejectReason.trim()) {
      setError('A rejection reason is required');
      return;
    }
    setIsSaving(true);
    setError(null);
    try {
      const updated = await rejectPrescription(id, rejectReason.trim());
      setPrescription(updated);
      setShowRejectForm(false);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to reject prescription');
    } finally {
      setIsSaving(false);
    }
  }

  if (!ready) return null;

  return (
    <>
      <Topbar title="Prescription Review" />
      <div className="page">
        <button className="btn" style={{ marginBottom: 16 }} onClick={() => router.push('/prescriptions')}>
          ← Back to pending list
        </button>

        {error && <div className="error-banner">{error}</div>}

        {isLoading || !prescription ? (
          <p className="muted">Loading…</p>
        ) : (
          <>
            <div className="card">
              <h2>
                Status: <StatusBadge status={prescription.status} />
              </h2>
              <p>
                <strong>{prescription.user.name}</strong> ({prescription.user.phone})
                {prescription.user.address ? ` • ${prescription.user.address}` : ''}
              </p>
              <p className="muted">Uploaded {new Date(prescription.createdAt).toLocaleString()}</p>
              {prescription.reviewedBy && (
                <p className="muted">Reviewed by {prescription.reviewedBy.name}</p>
              )}
              {prescription.status === 'REJECTED' && prescription.rejectionReason && (
                <div className="error-banner">Rejected: {prescription.rejectionReason}</div>
              )}
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={prescription.imageUrl}
                alt="Prescription"
                className="prescription-image"
              />
            </div>

            <div className="card">
              <h2>Medicines</h2>
              {rows.length === 0 && <p className="muted">No medicines entered yet.</p>}
              {rows.map((row, index) => (
                <MedicineRowEditor
                  key={row.key}
                  row={row}
                  disabled={!isPending || isSaving}
                  onChange={(next) => updateRow(index, next)}
                  onRemove={() => removeRow(index)}
                />
              ))}
              {isPending && (
                <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
                  <button className="btn" onClick={addRow} disabled={isSaving}>
                    + Add medicine
                  </button>
                  <button className="btn btn-primary" onClick={handleSaveMedicines} disabled={isSaving}>
                    Save medicines
                  </button>
                </div>
              )}
            </div>

            {isPending && (
              <div className="card">
                <h2>Decision</h2>
                <p className="muted">
                  Completing generates the deterministic medicine routine from the schedule data
                  above — every medicine needs times/day, dose times, and duration filled in first.
                </p>
                <div style={{ display: 'flex', gap: 12, marginBottom: showRejectForm ? 12 : 0 }}>
                  <button
                    className="btn btn-primary"
                    onClick={handleComplete}
                    disabled={isSaving || rows.length === 0}
                  >
                    Complete prescription
                  </button>
                  <button
                    className="btn btn-danger"
                    onClick={() => setShowRejectForm((v) => !v)}
                    disabled={isSaving}
                  >
                    Reject prescription
                  </button>
                </div>
                {showRejectForm && (
                  <div className="field">
                    <label>Rejection reason</label>
                    <textarea
                      rows={3}
                      value={rejectReason}
                      onChange={(e) => setRejectReason(e.target.value)}
                    />
                    <button
                      className="btn btn-danger"
                      style={{ marginTop: 8 }}
                      onClick={handleReject}
                      disabled={isSaving}
                    >
                      Confirm rejection
                    </button>
                  </div>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </>
  );
}
