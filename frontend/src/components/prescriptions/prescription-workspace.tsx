'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  ApiError,
  DiagnosticTest,
  Doctor,
  DoctorInput,
  Lookups,
  PrescriptionDetail,
  PrescriptionDetailsInput,
  completePrescription,
  createTest,
  getLookups,
  getPrescription,
  rejectPrescription,
  removeMedicine,
  saveMedicines,
  savePrescriptionDetails,
  searchDoctors,
  searchTests,
} from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { PatientName } from '@/components/patient-name';
import { StatusBadge } from '@/components/status-badge';
import { Autosuggest } from '@/components/autosuggest';
import {
  MedicineFormRow,
  MedicineRowEditor,
  MedicineSummary,
  emptyRow,
  medicineToRow,
  rowProblems,
  rowToEntry,
} from '@/components/medicine-form';
import { ButtonSpinner, Skeleton } from '@/components/skeleton';
import { useToast } from '@/components/toast';
import { useConfirm } from '@/components/confirm-dialog';
import { ErrorBanner } from '@/components/error-banner';

let tmpRowCounter = 0;

type DoctorMode = 'none' | 'existing' | 'new' | 'na';

interface DoctorState {
  mode: DoctorMode;
  existing: Doctor | null;
  query: string; // what is typed in the name box
  draft: { bmdcNumber: string; specialtyId: string; chamber: string; phone: string; districtId: string };
}

const EMPTY_DOCTOR_DRAFT = { bmdcNumber: '', specialtyId: '', chamber: '', phone: '', districtId: '' };

function doctorFrom(p: PrescriptionDetail): DoctorState {
  return p.doctor
    ? { mode: 'existing', existing: p.doctor, query: p.doctor.name, draft: EMPTY_DOCTOR_DRAFT }
    : { mode: 'none', existing: null, query: '', draft: EMPTY_DOCTOR_DRAFT };
}

function doctorPayload(d: DoctorState): Pick<PrescriptionDetailsInput, 'doctorId' | 'doctor' | 'doctorNotApplicable'> {
  if (d.mode === 'na') return { doctorNotApplicable: true };
  if (d.mode === 'existing' && d.existing) return { doctorId: d.existing.id };
  if (d.mode === 'new' && d.query.trim().length >= 2) {
    const doctor: DoctorInput = { name: d.query.trim() };
    if (d.draft.bmdcNumber.trim()) doctor.bmdcNumber = d.draft.bmdcNumber.trim();
    if (d.draft.specialtyId) doctor.specialtyId = Number(d.draft.specialtyId);
    if (d.draft.chamber.trim()) doctor.chamber = d.draft.chamber.trim();
    if (d.draft.phone.trim()) doctor.phone = d.draft.phone.trim();
    if (d.draft.districtId) doctor.districtId = Number(d.draft.districtId);
    return { doctor };
  }
  return {};
}

function dateOnly(iso: string | null) {
  return iso ? iso.slice(0, 10) : '';
}

/**
 * The pharmacist's prescription form, next to the photo. Admins (and any
 * prescription that left PENDING) get the same screen read-only.
 */
export function PrescriptionWorkspace({
  id,
  basePath,
  readOnly: forceReadOnly,
  back = { href: basePath, label: 'Queue' },
}: {
  id: string;
  basePath: string;
  readOnly: boolean;
  /** Where the back button goes (the admin area has no queue: the audit log). */
  back?: { href: string; label: string };
}) {
  const [prescription, setPrescription] = useState<PrescriptionDetail | null>(null);
  const [lookups, setLookups] = useState<Lookups | null>(null);
  const [doctor, setDoctor] = useState<DoctorState>({ mode: 'none', existing: null, query: '', draft: EMPTY_DOCTOR_DRAFT });
  const [visitDate, setVisitDate] = useState('');
  const [nextVisitDate, setNextVisitDate] = useState('');
  const [diagnosis, setDiagnosis] = useState('');
  const [tests, setTests] = useState<DiagnosticTest[]>([]);
  const [testQuery, setTestQuery] = useState('');
  const [rows, setRows] = useState<MedicineFormRow[]>([]);
  const [expandedKey, setExpandedKey] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();
  const confirm = useConfirm();
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  function apply(p: PrescriptionDetail) {
    setPrescription(p);
    setDoctor(doctorFrom(p));
    setVisitDate(dateOnly(p.visitDate));
    setNextVisitDate(dateOnly(p.nextVisitDate));
    setDiagnosis(p.diagnosis ?? '');
    setTests(p.tests.map((t) => t.test));
    setRows(p.medicines.map(medicineToRow));
    setExpandedKey(null);
  }

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [p, l] = await Promise.all([getPrescription(id), getLookups()]);
      setLookups(l);
      apply(p);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load prescription');
    } finally {
      setIsLoading(false);
    }
  }

  const readOnly = forceReadOnly || prescription?.status !== 'PENDING';
  const mealTimings = lookups?.mealTimings ?? [];

  // --- Medicines ---

  function updateRow(key: string, next: MedicineFormRow) {
    setRows((prev) => prev.map((r) => (r.key === key ? next : r)));
  }

  /** "Add new" collapses the line being edited to its one-line summary. */
  function addRow() {
    const row = emptyRow(`tmp-${tmpRowCounter++}`);
    setRows((prev) => [...prev, row]);
    setExpandedKey(row.key);
  }

  async function removeRow(row: MedicineFormRow) {
    if (!row.id) {
      setRows((prev) => prev.filter((r) => r.key !== row.key));
      return;
    }
    const ok = await confirm({
      title: `Remove ${row.medicineName || 'this medicine'}?`,
      confirmLabel: 'Remove',
      danger: true,
    });
    if (!ok) return;
    await run('Failed to remove medicine', async () => {
      const updated = await removeMedicine(id, row.id!);
      // Keep unsaved edits on the other lines.
      setPrescription(updated);
      setRows((prev) => prev.filter((r) => r.key !== row.key));
    });
  }

  // --- Tests ---

  function addTest(test: DiagnosticTest) {
    setTests((prev) => (prev.some((t) => t.id === test.id) ? prev : [...prev, test]));
    setTestQuery('');
  }

  async function addNewTest() {
    const name = testQuery.trim();
    if (!name) return;
    await run('Failed to add test', async () => addTest(await createTest(name)));
  }

  // --- Save / complete / reject ---

  async function run(fallback: string, action: () => Promise<void>) {
    setIsSaving(true);
    setError(null);
    try {
      await action();
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : fallback);
    } finally {
      setIsSaving(false);
    }
  }

  async function saveAll() {
    await savePrescriptionDetails(id, {
      ...doctorPayload(doctor),
      visitDate: visitDate || null,
      nextVisitDate: nextVisitDate || null,
      diagnosis: diagnosis.trim() || null,
      testIds: tests.map((t) => t.id),
    });
    const entries = rows.filter((r) => r.medicineName.trim()).map((r) => rowToEntry(r, mealTimings));
    return saveMedicines(id, entries);
  }

  function handleSave() {
    return run('Failed to save', async () => {
      apply(await saveAll());
      toast.success('Saved.');
    });
  }

  async function handleComplete() {
    const incomplete = rows.filter((r) => rowProblems(r).length > 0);
    if (rows.length === 0) {
      setError('Add at least one medicine first.');
      return;
    }
    if (incomplete.length > 0) {
      setError(`Finish these medicines first: ${incomplete.map((r) => r.medicineName || 'unnamed').join(', ')}`);
      setExpandedKey(incomplete[0].key);
      return;
    }
    const ok = await confirm({
      title: 'Send to the patient?',
      message: 'The patient confirms it in the app. It can no longer be edited here.',
      confirmLabel: 'Send',
    });
    if (!ok) return;
    return run('Failed to send prescription', async () => {
      await saveAll();
      apply(await completePrescription(id));
      toast.success('Sent. The patient will confirm it in the app; reminders start after that.');
    });
  }

  function handleReject() {
    if (rejectReason.trim().length < 3) {
      setError('Write a short note for the patient (at least 3 characters).');
      return;
    }
    return run('Failed to reject prescription', async () => {
      apply(await rejectPrescription(id, rejectReason.trim()));
      setShowRejectForm(false);
    });
  }

  if (isLoading) {
    return (
      <>
        <Topbar title="Prescription" />
        <div className="page">
          <Skeleton kind="detail" />
        </div>
      </>
    );
  }
  if (!prescription || !lookups) {
    return (
      <>
        <Topbar title="Prescription" />
        <div className="page">
          {error && <ErrorBanner message={error} onRetry={load} />}
          <Link href={back.href} className="btn">
            ← Back to {back.label.toLowerCase()}
          </Link>
        </div>
      </>
    );
  }

  const p = prescription;

  return (
    <>
      <Topbar
        title={`Prescription — ${p.user.name}`}
        actions={
          <Link href={back.href} className="btn">
            ← {back.label}
          </Link>
        }
      />
      <div className="page page-wide">
        {error && <div className="error-banner">{error}</div>}

        <div className="workspace">
          <section className="workspace-image">
            <div className="card">
              {p.imageUrl ? (
                <>
                  <a href={p.imageUrl} target="_blank" rel="noreferrer" title="Open full size">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={p.imageUrl} alt="Prescription photo" className="prescription-image" />
                  </a>
                  <p className="muted" style={{ marginTop: 8 }}>
                    Tap the photo to open it full size.
                  </p>
                </>
              ) : (
                // The patient deleted their account; the photo was erased with it.
                <div className="empty-state">Photo deleted</div>
              )}
            </div>
          </section>

          <section className="workspace-form">
            <div className="card">
              <div className="card-head">
                <StatusBadge status={p.status} />
                <span className="muted">Uploaded {new Date(p.createdAt).toLocaleString()}</span>
              </div>
              <p style={{ margin: '8px 0 0' }}>
                <strong>
                  <PatientName user={p.user} />
                </strong>
              </p>
              {p.reviewedBy && (
                <p className="muted">
                  Reviewed by {p.reviewedBy.name}
                  {p.reviewedAt ? ` · ${new Date(p.reviewedAt).toLocaleString()}` : ''}
                </p>
              )}
              {p.status === 'REJECTED' && p.rejectionReason && (
                <div className="error-banner" style={{ marginTop: 12, marginBottom: 0 }}>
                  Feedback sent to patient: {p.rejectionReason}
                </div>
              )}
              {p.previous && (
                <div className="info-banner">
                  Re-upload of a rejected prescription
                  {p.previous.rejectionReason ? `. Earlier feedback: “${p.previous.rejectionReason}”` : ''}{' '}
                  <Link href={`${basePath}/${p.previous.id}`}>View earlier upload</Link>
                </div>
              )}
            </div>

            <div className="card">
              <h2>Doctor</h2>
              {readOnly ? (
                p.doctor ? (
                  <p>
                    <strong>{p.doctor.name}</strong>
                    {p.doctor.specialty && <span className="muted"> · {p.doctor.specialty.name}</span>}
                    {p.doctor.bmdcNumber && <span className="muted"> · BMDC {p.doctor.bmdcNumber}</span>}
                  </p>
                ) : (
                  <p className="muted">Not recorded.</p>
                )
              ) : (
                <DoctorBlock value={doctor} onChange={setDoctor} lookups={lookups} disabled={isSaving} />
              )}
            </div>

            <div className="card">
              <h2>Visit</h2>
              <div className="form-grid">
                <div className="field">
                  <label htmlFor="visit-date">Visit date</label>
                  <input
                    id="visit-date"
                    type="date"
                    className="input"
                    value={visitDate}
                    onChange={(e) => setVisitDate(e.target.value)}
                    disabled={readOnly || isSaving}
                  />
                </div>
                <div className="field">
                  <label htmlFor="next-visit">Next visit date</label>
                  <input
                    id="next-visit"
                    type="date"
                    className="input"
                    value={nextVisitDate}
                    onChange={(e) => setNextVisitDate(e.target.value)}
                    disabled={readOnly || isSaving}
                  />
                </div>
                <div className="field span-2">
                  <label htmlFor="diagnosis">Diagnosis</label>
                  <textarea
                    id="diagnosis"
                    rows={2}
                    value={diagnosis}
                    onChange={(e) => setDiagnosis(e.target.value)}
                    disabled={readOnly || isSaving}
                    placeholder="As written on the prescription"
                  />
                </div>
              </div>
            </div>

            <div className="card">
              <h2>Tests</h2>
              {tests.length === 0 && readOnly && <p className="muted">None.</p>}
              {tests.length > 0 && (
                <div className="chips">
                  {tests.map((t) => (
                    <span key={t.id} className="chip">
                      {t.name}
                      {!readOnly && (
                        <button
                          type="button"
                          aria-label={`Remove ${t.name}`}
                          onClick={() => setTests((prev) => prev.filter((x) => x.id !== t.id))}
                          disabled={isSaving}
                        >
                          ×
                        </button>
                      )}
                    </span>
                  ))}
                </div>
              )}
              {!readOnly && (
                <div className="inline-add">
                  <Autosuggest<DiagnosticTest>
                    value={testQuery}
                    onChange={setTestQuery}
                    search={searchTests}
                    getKey={(t) => t.id}
                    renderItem={(t) => t.name}
                    onPick={addTest}
                    placeholder="Add a test, e.g. CBC"
                    disabled={isSaving}
                  />
                  <button
                    type="button"
                    className="btn"
                    onClick={addNewTest}
                    disabled={isSaving || !testQuery.trim()}
                  >
                    Add as new
                  </button>
                </div>
              )}
            </div>

            <div className="card">
              <h2>Medicines</h2>
              {rows.length === 0 && <p className="muted">No medicines entered yet.</p>}
              {rows.map((row) =>
                !readOnly && expandedKey === row.key ? (
                  <MedicineRowEditor
                    key={row.key}
                    row={row}
                    mealTimings={mealTimings}
                    disabled={isSaving}
                    onChange={(next) => updateRow(row.key, next)}
                    onRemove={() => removeRow(row)}
                    onDone={() => setExpandedKey(null)}
                  />
                ) : (
                  <MedicineSummary
                    key={row.key}
                    row={row}
                    mealTimings={mealTimings}
                    readOnly={readOnly}
                    disabled={isSaving}
                    onEdit={() => setExpandedKey(row.key)}
                    onRemove={() => removeRow(row)}
                  />
                ),
              )}
              {!readOnly && (
                <button className="btn" onClick={addRow} disabled={isSaving}>
                  + Add new medicine
                </button>
              )}
            </div>

            {!readOnly && (
              <div className="card decision-bar">
                <div className="button-row">
                  <button className="btn" onClick={handleSave} disabled={isSaving}>
                    {isSaving && <ButtonSpinner />}{isSaving ? 'Saving…' : 'Save draft'}
                  </button>
                  <button className="btn btn-primary" onClick={handleComplete} disabled={isSaving}>
                    Send for confirmation
                  </button>
                  <button
                    className="btn btn-danger"
                    onClick={() => setShowRejectForm((v) => !v)}
                    disabled={isSaving}
                  >
                    Reject
                  </button>
                </div>
                <p className="muted" style={{ marginBottom: 0 }}>
                  The patient confirms or edits the routine in the app; reminders start after that.
                </p>
                {showRejectForm && (
                  <div className="field" style={{ marginTop: 12 }}>
                    <label htmlFor="reject-reason">Feedback for the patient</label>
                    <textarea
                      id="reject-reason"
                      rows={3}
                      value={rejectReason}
                      onChange={(e) => setRejectReason(e.target.value)}
                      placeholder="e.g. The photo is blurry. Please upload a clearer photo of the whole page."
                      maxLength={500}
                    />
                    <p className="hint">The app shows this note with a Re-upload button.</p>
                    <button className="btn btn-danger" onClick={handleReject} disabled={isSaving}>
                      Reject and send feedback
                    </button>
                  </div>
                )}
              </div>
            )}
          </section>
        </div>
      </div>
    </>
  );
}

/** Pick an existing doctor, type a new one (creates a doctor record), or Not applicable. */
function DoctorBlock({
  value,
  onChange,
  lookups,
  disabled,
}: {
  value: DoctorState;
  onChange: (d: DoctorState) => void;
  lookups: Lookups;
  disabled: boolean;
}) {
  const na = value.mode === 'na';
  const setDraft = (key: keyof DoctorState['draft'], v: string) =>
    onChange({ ...value, draft: { ...value.draft, [key]: v } });

  return (
    <>
      <label className="checkbox" style={{ marginBottom: 12 }}>
        <input
          type="checkbox"
          checked={na}
          onChange={(e) =>
            onChange(
              e.target.checked
                ? { ...value, mode: 'na' }
                : { ...value, mode: value.existing ? 'existing' : value.query.trim() ? 'new' : 'none' },
            )
          }
          disabled={disabled}
        />
        Not applicable (no doctor on this prescription)
      </label>

      {!na && (
        <>
          <div className="field">
            <label htmlFor="doctor-name">Doctor name</label>
            <Autosuggest<Doctor>
              id="doctor-name"
              value={value.query}
              onChange={(text) =>
                onChange({ ...value, query: text, existing: null, mode: text.trim() ? 'new' : 'none' })
              }
              search={searchDoctors}
              getKey={(d) => d.id}
              renderItem={(d) => (
                <>
                  <strong>{d.name}</strong>
                  {d.specialty && <span className="muted"> · {d.specialty.name}</span>}
                  {d.bmdcNumber && <div className="muted">BMDC {d.bmdcNumber}</div>}
                </>
              )}
              onPick={(d) => onChange({ ...value, mode: 'existing', existing: d, query: d.name })}
              placeholder="Start typing the doctor's name"
              disabled={disabled}
            />
          </div>

          {value.mode === 'existing' && value.existing && (
            <p className="muted">
              Linked to the saved doctor
              {value.existing.specialty ? ` (${value.existing.specialty.name})` : ''}.
            </p>
          )}

          {value.mode === 'new' && (
            <>
              <p className="hint">New doctor: a doctor record is created when you save.</p>
              <div className="form-grid">
                <div className="field">
                  <label htmlFor="doctor-bmdc">BMDC number (optional)</label>
                  <input
                    id="doctor-bmdc"
                    className="input"
                    value={value.draft.bmdcNumber}
                    onChange={(e) => setDraft('bmdcNumber', e.target.value)}
                    disabled={disabled}
                    placeholder="e.g. A-12345"
                  />
                </div>
                <div className="field">
                  <label htmlFor="doctor-specialty">Specialty (optional)</label>
                  <select
                    id="doctor-specialty"
                    value={value.draft.specialtyId}
                    onChange={(e) => setDraft('specialtyId', e.target.value)}
                    disabled={disabled}
                  >
                    <option value="">Not specified</option>
                    {lookups.doctorSpecialties.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="doctor-chamber">Chamber / address (optional)</label>
                  <input
                    id="doctor-chamber"
                    className="input"
                    value={value.draft.chamber}
                    onChange={(e) => setDraft('chamber', e.target.value)}
                    disabled={disabled}
                  />
                </div>
                <div className="field">
                  <label htmlFor="doctor-district">District (optional)</label>
                  <select
                    id="doctor-district"
                    value={value.draft.districtId}
                    onChange={(e) => setDraft('districtId', e.target.value)}
                    disabled={disabled}
                  >
                    <option value="">Not specified</option>
                    {lookups.districts.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label htmlFor="doctor-phone">Chamber phone (optional)</label>
                  <input
                    id="doctor-phone"
                    className="input"
                    inputMode="tel"
                    value={value.draft.phone}
                    onChange={(e) => setDraft('phone', e.target.value)}
                    disabled={disabled}
                  />
                </div>
              </div>
            </>
          )}
        </>
      )}
    </>
  );
}
