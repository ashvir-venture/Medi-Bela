'use client';

import { MedicineEntryInput, PrescriptionMedicine } from '@/lib/api-client';

export interface MedicineFormRow {
  key: string; // stable React key; equals existing id, or a generated tmp id for new rows
  id?: string; // present once persisted server-side
  medicineName: string;
  dosage: string;
  frequency: string;
  duration: string;
  instructions: string;
  timesPerDay: string; // kept as strings while editing; parsed on save
  scheduleTimes: string; // comma-separated "08:00, 20:00"
  durationDays: string;
  startDate: string; // yyyy-mm-dd or ''
  verified: boolean;
}

export function medicineToRow(m: PrescriptionMedicine): MedicineFormRow {
  let scheduleTimes = '';
  try {
    const parsed = m.scheduleTimes ? JSON.parse(m.scheduleTimes) : [];
    scheduleTimes = Array.isArray(parsed) ? parsed.join(', ') : '';
  } catch {
    scheduleTimes = '';
  }
  return {
    key: m.id,
    id: m.id,
    medicineName: m.medicineName,
    dosage: m.dosage,
    frequency: m.frequency,
    duration: m.duration,
    instructions: m.instructions ?? '',
    timesPerDay: m.timesPerDay?.toString() ?? '',
    scheduleTimes,
    durationDays: m.durationDays?.toString() ?? '',
    startDate: m.startDate ? m.startDate.slice(0, 10) : '',
    verified: m.verified,
  };
}

export function emptyRow(key: string): MedicineFormRow {
  return {
    key,
    medicineName: '',
    dosage: '',
    frequency: '',
    duration: '',
    instructions: '',
    timesPerDay: '',
    scheduleTimes: '',
    durationDays: '',
    startDate: '',
    verified: false,
  };
}

/** Converts a form row back into the API payload shape. Blank/invalid
 * numeric fields are simply omitted, which the backend treats as "not
 * ready for completion yet" — it never guesses on our behalf. */
export function rowToEntry(row: MedicineFormRow): MedicineEntryInput {
  const timesPerDay = row.timesPerDay.trim() ? Number(row.timesPerDay) : undefined;
  const durationDays = row.durationDays.trim() ? Number(row.durationDays) : undefined;
  const scheduleTimes = row.scheduleTimes.trim()
    ? row.scheduleTimes.split(',').map((t) => t.trim()).filter(Boolean)
    : undefined;

  return {
    id: row.id,
    medicineName: row.medicineName.trim(),
    dosage: row.dosage.trim(),
    frequency: row.frequency.trim(),
    duration: row.duration.trim(),
    instructions: row.instructions.trim() || undefined,
    timesPerDay,
    durationDays,
    scheduleTimes,
    startDate: row.startDate || undefined,
  };
}

export function MedicineRowEditor({
  row,
  onChange,
  onRemove,
  disabled,
}: {
  row: MedicineFormRow;
  onChange: (row: MedicineFormRow) => void;
  onRemove: () => void;
  disabled: boolean;
}) {
  function set<K extends keyof MedicineFormRow>(key: K, value: MedicineFormRow[K]) {
    onChange({ ...row, [key]: value });
  }

  return (
    <div className="medicine-card">
      {row.verified && <span className="badge badge-completed verified-badge">Verified</span>}
      <div className="row">
        <div className="field">
          <label>Medicine name</label>
          <input
            className="input"
            value={row.medicineName}
            onChange={(e) => set('medicineName', e.target.value)}
            disabled={disabled}
            placeholder="e.g. Amoxicillin"
          />
        </div>
        <div className="field">
          <label>Dosage</label>
          <input
            className="input"
            value={row.dosage}
            onChange={(e) => set('dosage', e.target.value)}
            disabled={disabled}
            placeholder="e.g. 250mg"
          />
        </div>
      </div>
      <div className="row">
        <div className="field">
          <label>Frequency (display text)</label>
          <input
            className="input"
            value={row.frequency}
            onChange={(e) => set('frequency', e.target.value)}
            disabled={disabled}
            placeholder="e.g. three times daily"
          />
        </div>
        <div className="field">
          <label>Duration (display text)</label>
          <input
            className="input"
            value={row.duration}
            onChange={(e) => set('duration', e.target.value)}
            disabled={disabled}
            placeholder="e.g. 7 days"
          />
        </div>
      </div>
      <div className="field">
        <label>Instructions (optional)</label>
        <input
          className="input"
          value={row.instructions}
          onChange={(e) => set('instructions', e.target.value)}
          disabled={disabled}
          placeholder="e.g. after meal"
        />
      </div>

      <p className="muted" style={{ margin: '12px 0 8px' }}>
        Schedule (required before completion — used to generate the routine; nothing here is
        inferred automatically)
      </p>
      <div className="row">
        <div className="field">
          <label>Times per day</label>
          <input
            type="number"
            min={1}
            max={12}
            className="input"
            value={row.timesPerDay}
            onChange={(e) => set('timesPerDay', e.target.value)}
            disabled={disabled}
          />
        </div>
        <div className="field">
          <label>Duration (days)</label>
          <input
            type="number"
            min={1}
            max={365}
            className="input"
            value={row.durationDays}
            onChange={(e) => set('durationDays', e.target.value)}
            disabled={disabled}
          />
        </div>
      </div>
      <div className="row">
        <div className="field">
          <label>Dose times (24h, comma-separated, e.g. 08:00, 20:00)</label>
          <input
            className="input"
            value={row.scheduleTimes}
            onChange={(e) => set('scheduleTimes', e.target.value)}
            disabled={disabled}
            placeholder="08:00, 20:00"
          />
        </div>
        <div className="field">
          <label>Start date (optional — defaults to completion date)</label>
          <input
            type="date"
            className="input"
            value={row.startDate}
            onChange={(e) => set('startDate', e.target.value)}
            disabled={disabled}
          />
        </div>
      </div>
      <button type="button" className="btn btn-danger" onClick={onRemove} disabled={disabled}>
        Remove medicine
      </button>
    </div>
  );
}
