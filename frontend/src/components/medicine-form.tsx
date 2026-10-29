'use client';

import {
  CatalogMedicine,
  LookupRow,
  MedicineEntryInput,
  PrescriptionMedicine,
  searchMedicines,
} from '@/lib/api-client';
import { Autosuggest } from '@/components/autosuggest';

/** One medicine line while the pharmacist edits it (numbers kept as strings). */
export interface MedicineFormRow {
  key: string; // stable React key; equals existing id, or a generated tmp id for new rows
  id?: string; // present once persisted server-side
  medicineId: string | null; // catalog row; null = typed name, linked/created on save
  medicineName: string;
  formName: string | null;
  strength: string;
  doseAmount: string;
  timesPerDay: string;
  scheduleTimes: string[]; // "HH:mm", one per dose
  mealTimingId: string;
  durationDays: string;
  continuous: boolean;
  startDate: string; // yyyy-mm-dd or ''
  instructions: string;
  verified: boolean;
}

export function medicineToRow(m: PrescriptionMedicine): MedicineFormRow {
  let scheduleTimes: string[] = [];
  try {
    const parsed = m.scheduleTimes ? JSON.parse(m.scheduleTimes) : [];
    scheduleTimes = Array.isArray(parsed) ? parsed : [];
  } catch {
    scheduleTimes = [];
  }
  return {
    key: m.id,
    id: m.id,
    medicineId: m.medicineId,
    medicineName: m.medicineName,
    formName: m.medicine?.form?.name ?? null,
    strength: m.strength ?? '',
    doseAmount: m.doseAmount ?? '',
    timesPerDay: m.timesPerDay?.toString() ?? '',
    scheduleTimes,
    mealTimingId: m.mealTimingId?.toString() ?? '',
    durationDays: m.durationDays?.toString() ?? '',
    continuous: m.continuous,
    startDate: m.startDate ? m.startDate.slice(0, 10) : '',
    instructions: m.instructions ?? '',
    verified: m.verified,
  };
}

export function emptyRow(key: string): MedicineFormRow {
  return {
    key,
    medicineId: null,
    medicineName: '',
    formName: null,
    strength: '',
    doseAmount: '',
    timesPerDay: '',
    scheduleTimes: [],
    mealTimingId: '',
    durationDays: '',
    continuous: false,
    startDate: '',
    instructions: '',
    verified: false,
  };
}

function plural(n: number, one: string, many: string) {
  return `${n} ${n === 1 ? one : many}`;
}

/** What is still missing before the prescription can be sent (mirrors the backend check). */
export function rowProblems(row: MedicineFormRow): string[] {
  const problems: string[] = [];
  if (!row.medicineName.trim()) problems.push('medicine');
  const times = Number(row.timesPerDay);
  if (!times) problems.push('times per day');
  else if (row.scheduleTimes.filter(Boolean).length !== times) problems.push('dose times');
  if (!row.continuous && !Number(row.durationDays)) problems.push('duration');
  return problems;
}

/**
 * Payload for the API. The free-text display fields (dosage, frequency,
 * duration) are composed from the structured ones so the app keeps showing
 * readable text; routine generation only reads the structured fields.
 * Blank numbers are omitted: the backend then refuses completion rather
 * than guessing.
 */
export function rowToEntry(row: MedicineFormRow, mealTimings: LookupRow[]): MedicineEntryInput {
  const timesPerDay = Number(row.timesPerDay) || undefined;
  const durationDays = row.continuous ? undefined : Number(row.durationDays) || undefined;
  const mealTimingId = Number(row.mealTimingId) || undefined;
  const meal = mealTimings.find((m) => m.id === mealTimingId)?.name;
  const scheduleTimes = row.scheduleTimes.filter(Boolean);

  return {
    id: row.id,
    medicineId: row.medicineId ?? undefined,
    medicineName: row.medicineName.trim(),
    strength: row.strength.trim() || undefined,
    doseAmount: row.doseAmount.trim() || undefined,
    dosage: [row.strength.trim(), row.doseAmount.trim()].filter(Boolean).join(', ') || '-',
    frequency: timesPerDay
      ? [`${plural(timesPerDay, 'time', 'times')} a day`, meal].filter(Boolean).join(', ')
      : '-',
    duration: row.continuous ? 'Continuous' : durationDays ? plural(durationDays, 'day', 'days') : '-',
    instructions: row.instructions.trim() || undefined,
    timesPerDay,
    scheduleTimes: scheduleTimes.length ? scheduleTimes : undefined,
    durationDays,
    continuous: row.continuous,
    mealTimingId,
    startDate: row.startDate || undefined,
  };
}

/** The collapsed one-line view of a medicine line. */
export function MedicineSummary({
  row,
  mealTimings,
  onEdit,
  onRemove,
  disabled,
  readOnly,
}: {
  row: MedicineFormRow;
  mealTimings: LookupRow[];
  onEdit: () => void;
  onRemove: () => void;
  disabled: boolean;
  readOnly: boolean;
}) {
  const times = Number(row.timesPerDay);
  const meal = mealTimings.find((m) => String(m.id) === row.mealTimingId)?.name;
  const parts = [
    [row.strength, row.doseAmount].filter(Boolean).join(', '),
    times ? `${times}×/day${row.scheduleTimes.length ? ` (${row.scheduleTimes.join(', ')})` : ''}` : '',
    meal ?? '',
    row.continuous ? 'continuous' : row.durationDays ? `${row.durationDays} days` : '',
  ].filter(Boolean);
  const problems = rowProblems(row);

  return (
    <div className="line-summary">
      <div className="line-summary-text">
        <strong>{row.medicineName || 'Unnamed medicine'}</strong>
        {row.formName && <span className="muted"> · {row.formName}</span>}
        <div className="muted">{parts.join(' · ') || 'No schedule yet'}</div>
        {!readOnly && problems.length > 0 && (
          <div className="line-warning">Missing: {problems.join(', ')}</div>
        )}
      </div>
      {!readOnly && (
        <div className="line-summary-actions">
          <button type="button" className="btn btn-sm" onClick={onEdit} disabled={disabled}>
            Edit
          </button>
          <button type="button" className="btn btn-sm btn-danger" onClick={onRemove} disabled={disabled}>
            Remove
          </button>
        </div>
      )}
    </div>
  );
}

export function MedicineRowEditor({
  row,
  mealTimings,
  onChange,
  onRemove,
  onDone,
  disabled,
}: {
  row: MedicineFormRow;
  mealTimings: LookupRow[];
  onChange: (row: MedicineFormRow) => void;
  onRemove: () => void;
  onDone: () => void;
  disabled: boolean;
}) {
  function set<K extends keyof MedicineFormRow>(key: K, value: MedicineFormRow[K]) {
    onChange({ ...row, [key]: value });
  }

  function setTimesPerDay(value: string) {
    const n = Math.min(12, Math.max(0, Number(value) || 0));
    // Keep entered times; add or drop empty slots to match the count.
    const scheduleTimes = Array.from({ length: n }, (_, i) => row.scheduleTimes[i] ?? '');
    onChange({ ...row, timesPerDay: value, scheduleTimes });
  }

  function setTime(index: number, value: string) {
    set(
      'scheduleTimes',
      row.scheduleTimes.map((t, i) => (i === index ? value : t)),
    );
  }

  return (
    <div className="medicine-card">
      <div className="form-grid">
        <div className="field span-2">
          <label htmlFor={`${row.key}-name`}>Medicine (brand or generic name)</label>
          <Autosuggest<CatalogMedicine>
            id={`${row.key}-name`}
            value={row.medicineName}
            onChange={(text) => onChange({ ...row, medicineName: text, medicineId: null, formName: null })}
            search={searchMedicines}
            getKey={(m) => m.id}
            renderItem={(m) => (
              <>
                <strong>{m.brandName}</strong>
                {m.form && <span className="muted"> · {m.form.name}</span>}
                {m.genericName && <div className="muted">{m.genericName}</div>}
              </>
            )}
            onPick={(m) =>
              onChange({ ...row, medicineId: m.id, medicineName: m.brandName, formName: m.form?.name ?? null })
            }
            placeholder="Start typing, e.g. Napa"
            disabled={disabled}
            autoFocus={!row.medicineName}
          />
          {row.medicineName.trim() && !row.medicineId && (
            <p className="hint">New medicine: it will be added to the catalog for you to complete later.</p>
          )}
        </div>
        <div className="field">
          <label htmlFor={`${row.key}-strength`}>Strength</label>
          <input
            id={`${row.key}-strength`}
            className="input"
            value={row.strength}
            onChange={(e) => set('strength', e.target.value)}
            disabled={disabled}
            placeholder="e.g. 500 mg"
          />
        </div>
        <div className="field">
          <label htmlFor={`${row.key}-dose`}>Dose amount</label>
          <input
            id={`${row.key}-dose`}
            className="input"
            value={row.doseAmount}
            onChange={(e) => set('doseAmount', e.target.value)}
            disabled={disabled}
            placeholder="e.g. 1 tablet"
          />
        </div>
        <div className="field">
          <label htmlFor={`${row.key}-times`}>Times per day</label>
          <input
            id={`${row.key}-times`}
            type="number"
            min={1}
            max={12}
            className="input"
            value={row.timesPerDay}
            onChange={(e) => setTimesPerDay(e.target.value)}
            disabled={disabled}
          />
        </div>
        <div className="field">
          <label htmlFor={`${row.key}-meal`}>Meal timing</label>
          <select
            id={`${row.key}-meal`}
            value={row.mealTimingId}
            onChange={(e) => set('mealTimingId', e.target.value)}
            disabled={disabled}
          >
            <option value="">Not specified</option>
            {mealTimings.map((m) => (
              <option key={m.id} value={m.id}>
                {m.name}
              </option>
            ))}
          </select>
        </div>
        {row.scheduleTimes.length > 0 && (
          <div className="field span-2">
            <label>Dose times (24h)</label>
            <div className="time-row">
              {row.scheduleTimes.map((t, i) => (
                <input
                  key={i}
                  type="time"
                  className="input"
                  aria-label={`Dose ${i + 1} time`}
                  value={t}
                  onChange={(e) => setTime(i, e.target.value)}
                  disabled={disabled}
                />
              ))}
            </div>
          </div>
        )}
        <div className="field">
          <label htmlFor={`${row.key}-days`}>Duration (days)</label>
          <input
            id={`${row.key}-days`}
            type="number"
            min={1}
            max={365}
            className="input"
            value={row.continuous ? '' : row.durationDays}
            onChange={(e) => set('durationDays', e.target.value)}
            disabled={disabled || row.continuous}
            placeholder={row.continuous ? 'No end date' : ''}
          />
          <label className="checkbox">
            <input
              type="checkbox"
              checked={row.continuous}
              onChange={(e) => set('continuous', e.target.checked)}
              disabled={disabled}
            />
            Continuous (no end date)
          </label>
        </div>
        <div className="field">
          <label htmlFor={`${row.key}-start`}>Start date (optional)</label>
          <input
            id={`${row.key}-start`}
            type="date"
            className="input"
            value={row.startDate}
            onChange={(e) => set('startDate', e.target.value)}
            disabled={disabled}
          />
          <p className="hint">Empty = the day the patient confirms.</p>
        </div>
        <div className="field span-2">
          <label htmlFor={`${row.key}-instr`}>Instructions (optional)</label>
          <input
            id={`${row.key}-instr`}
            className="input"
            value={row.instructions}
            onChange={(e) => set('instructions', e.target.value)}
            disabled={disabled}
            placeholder="e.g. with plenty of water"
          />
        </div>
      </div>
      <div className="button-row">
        <button type="button" className="btn btn-primary btn-sm" onClick={onDone} disabled={disabled}>
          Done
        </button>
        <button type="button" className="btn btn-danger btn-sm" onClick={onRemove} disabled={disabled}>
          Remove
        </button>
      </div>
    </div>
  );
}
