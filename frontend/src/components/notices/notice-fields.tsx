'use client';

import { useEffect, useState } from 'react';
import { LookupRow, Notice, NoticeInput, getLookups } from '@/lib/api-client';

/** ISO string -> value for <input type="datetime-local"> in the browser's timezone. */
export function toLocalInput(iso: string | null) {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export interface NoticeFormValue {
  title: string;
  content: string;
  audience: 'ALL' | 'USER' | 'ADMIN';
  source: string;
  sourceUrl: string;
  startsAt: string; // datetime-local; empty = when published
  expiresAt: string; // datetime-local; empty = no expiry
  divisionIds: number[]; // empty = nationwide
}

export const EMPTY_NOTICE: NoticeFormValue = {
  title: '',
  content: '',
  audience: 'ALL',
  source: '',
  sourceUrl: '',
  startsAt: '',
  expiresAt: '',
  divisionIds: [],
};

export function noticeToForm(n: Notice): NoticeFormValue {
  return {
    title: n.title,
    content: n.content,
    audience: n.audience,
    source: n.source ?? '',
    sourceUrl: n.sourceUrl ?? '',
    startsAt: toLocalInput(n.startsAt),
    expiresAt: toLocalInput(n.expiresAt),
    divisionIds: n.divisions.map((d) => d.divisionId),
  };
}

/** Empty optional fields become null, which clears them on the server. */
export function formToInput(v: NoticeFormValue): NoticeInput {
  return {
    title: v.title.trim(),
    content: v.content.trim(),
    audience: v.audience,
    source: v.source.trim() || null,
    sourceUrl: v.sourceUrl.trim() || null,
    startsAt: v.startsAt ? new Date(v.startsAt).toISOString() : null,
    expiresAt: v.expiresAt ? new Date(v.expiresAt).toISOString() : null,
    divisionIds: v.divisionIds,
  };
}

/** The notice form shared by "New notice" and the notice page. */
export function NoticeFields({
  value,
  onChange,
  disabled,
}: {
  value: NoticeFormValue;
  onChange: (v: NoticeFormValue) => void;
  disabled?: boolean;
}) {
  const [divisions, setDivisions] = useState<LookupRow[]>([]);
  useEffect(() => {
    getLookups()
      .then((l) => setDivisions(l.divisions))
      .catch(() => setDivisions([]));
  }, []);

  const set = <K extends keyof NoticeFormValue>(key: K, v: NoticeFormValue[K]) => onChange({ ...value, [key]: v });
  const toggleDivision = (id: number) =>
    set(
      'divisionIds',
      value.divisionIds.includes(id) ? value.divisionIds.filter((d) => d !== id) : [...value.divisionIds, id],
    );

  return (
    <fieldset disabled={disabled} style={{ border: 'none', padding: 0, margin: 0 }}>
      <div className="field">
        <label htmlFor="notice-title">Title</label>
        <input id="notice-title" className="input" value={value.title} onChange={(e) => set('title', e.target.value)} required />
      </div>
      <div className="field">
        <label htmlFor="notice-content">Content</label>
        <textarea id="notice-content" rows={6} value={value.content} onChange={(e) => set('content', e.target.value)} required />
      </div>
      <div className="form-grid">
        <div className="field">
          <label htmlFor="notice-source">Source (optional)</label>
          <input
            id="notice-source"
            className="input"
            value={value.source}
            onChange={(e) => set('source', e.target.value)}
            placeholder="e.g. DGHS"
          />
        </div>
        <div className="field">
          <label htmlFor="notice-source-url">Source link (optional, https)</label>
          <input
            id="notice-source-url"
            className="input"
            type="url"
            value={value.sourceUrl}
            onChange={(e) => set('sourceUrl', e.target.value)}
            placeholder="https://"
          />
        </div>
        <div className="field">
          <label htmlFor="notice-audience">Audience</label>
          <select id="notice-audience" value={value.audience} onChange={(e) => set('audience', e.target.value as NoticeFormValue['audience'])}>
            <option value="ALL">Everyone</option>
            <option value="USER">Patients only</option>
            <option value="ADMIN">Admins/pharmacists only</option>
          </select>
        </div>
        <div className="field">
          <label htmlFor="notice-starts">Show from (optional)</label>
          <input
            id="notice-starts"
            type="datetime-local"
            className="input"
            value={value.startsAt}
            onChange={(e) => set('startsAt', e.target.value)}
          />
          <p className="hint">Empty = as soon as it is published. A later time schedules it; it is pushed then.</p>
        </div>
        <div className="field">
          <label htmlFor="notice-expires">Expires (optional)</label>
          <input
            id="notice-expires"
            type="datetime-local"
            className="input"
            value={value.expiresAt}
            onChange={(e) => set('expiresAt', e.target.value)}
          />
        </div>
      </div>
      <div className="field">
        <label>Divisions</label>
        <p className="hint" style={{ marginTop: 0 }}>None ticked = the whole country.</p>
        <div className="chips">
          {divisions.map((d) => (
            <label key={d.id} className="checkbox chip" style={{ margin: 0 }}>
              <input type="checkbox" checked={value.divisionIds.includes(d.id)} onChange={() => toggleDivision(d.id)} />
              {d.name}
            </label>
          ))}
        </div>
      </div>
    </fieldset>
  );
}
