'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  AdminUser,
  ApiError,
  AuditLogDetail,
  AuditLogRow,
  getAuditLog,
  getAuditLogFilters,
  listAuditLogs,
} from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { Topbar } from '@/components/topbar';
import { Pager, useCursorPager } from '@/components/pager';

type Actor = { id: string; name: string; role: AdminUser['role'] };

const ROLE_LABEL: Record<AdminUser['role'], string> = {
  ADMIN: 'Admin',
  PHARMACIST: 'Pharmacist',
  USER: 'Patient / caregiver',
};

/** Read-only records the admin area can open from an audit row. */
const ENTITY_PATH: Record<string, string> = {
  doctor: `${ADMIN_BASE}/doctors`,
  medicine: `${ADMIN_BASE}/medicines`,
  prescription: `${ADMIN_BASE}/prescriptions`,
  notice: `${ADMIN_BASE}/notices`,
};

const fmt = (iso: string) => new Date(iso).toLocaleString();

/**
 * Who changed what (append-only AuditLog), 20 per page, newest first.
 * Open a row to see the stored before / after values.
 */
export default function AuditLogPage() {
  const [actions, setActions] = useState<string[]>([]);
  const [actors, setActors] = useState<Actor[]>([]);
  const [action, setAction] = useState('');
  const [actor, setActor] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);

  useEffect(() => {
    getAuditLogFilters()
      .then((f) => {
        setActions(f.actions);
        setActors(f.actors);
      })
      .catch(() => undefined); // filters are optional; the list still works
  }, []);

  // `actor` is a staff id or "role:USER" (any patient / caregiver).
  const actorRole = actor.startsWith('role:') ? (actor.slice(5) as AdminUser['role']) : undefined;
  const actorId = actor && !actorRole ? actor : undefined;

  const pager = useCursorPager(
    (cursor) =>
      listAuditLogs({
        cursor,
        action: action || undefined,
        actorId,
        actorRole,
        from: from || undefined,
        to: to || undefined,
      }),
    `${action}|${actor}|${from}|${to}`,
  );

  function clear() {
    setAction('');
    setActor('');
    setFrom('');
    setTo('');
  }

  return (
    <>
      <Topbar title="Audit log" />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          Every recorded change: prescriptions prepared, rejected and confirmed, catalog edits,
          medicine changes, notice reviews and AI suggestion publishing. Read-only.
        </p>

        <div className="filter-bar">
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="audit-action">Action</label>
            <select id="audit-action" className="input" value={action} onChange={(e) => setAction(e.target.value)}>
              <option value="">All actions</option>
              {actions.map((a) => (
                <option key={a} value={a}>
                  {a}
                </option>
              ))}
            </select>
          </div>
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="audit-actor">Done by</label>
            <select id="audit-actor" className="input" value={actor} onChange={(e) => setActor(e.target.value)}>
              <option value="">Anyone</option>
              <option value="role:ADMIN">Any admin</option>
              <option value="role:PHARMACIST">Any pharmacist</option>
              <option value="role:USER">Any patient / caregiver</option>
              {actors.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name} ({ROLE_LABEL[a.role]})
                </option>
              ))}
            </select>
          </div>
          <div className="field" style={{ marginBottom: 0, flex: '0 1 170px' }}>
            <label htmlFor="audit-from">From</label>
            <input id="audit-from" type="date" className="input" value={from} max={to || undefined} onChange={(e) => setFrom(e.target.value)} />
          </div>
          <div className="field" style={{ marginBottom: 0, flex: '0 1 170px' }}>
            <label htmlFor="audit-to">To</label>
            <input id="audit-to" type="date" className="input" value={to} min={from || undefined} onChange={(e) => setTo(e.target.value)} />
          </div>
          {(action || actor || from || to) && (
            <button className="btn" onClick={clear}>
              Clear
            </button>
          )}
        </div>

        {pager.error && <div className="error-banner">{pager.error}</div>}

        {pager.isLoading && pager.items.length === 0 ? (
          <p className="muted">Loading…</p>
        ) : pager.items.length === 0 ? (
          <div className="empty-state">No audit entries found.</div>
        ) : (
          pager.items.map((row) => (
            <AuditRow
              key={row.id}
              row={row}
              open={openId === row.id}
              onToggle={() => setOpenId(openId === row.id ? null : row.id)}
            />
          ))
        )}

        <Pager
          pageNumber={pager.pageNumber}
          hasNext={pager.hasNext}
          hasPrevious={pager.hasPrevious}
          onNext={pager.next}
          onPrevious={pager.previous}
          disabled={pager.isLoading}
        />
      </div>
    </>
  );
}

function AuditRow({ row, open, onToggle }: { row: AuditLogRow; open: boolean; onToggle: () => void }) {
  const [detail, setDetail] = useState<AuditLogDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open || detail) return;
    getAuditLog(row.id)
      .then(setDetail)
      .catch((err) => setError(err instanceof ApiError ? err.message : 'Failed to load'));
  }, [open, detail, row.id]);

  const entityPath = row.entityId ? ENTITY_PATH[row.entityType] : undefined;

  return (
    <div className={`audit-row ${open ? 'open' : ''}`}>
      <button type="button" className="audit-row-head" onClick={onToggle} aria-expanded={open}>
        <div>
          <div>
            <code className="audit-action">{row.action}</code>
          </div>
          <div className="muted">
            {row.actor ? `${row.actor.name} (${ROLE_LABEL[row.actor.role]})` : 'Deleted account'}
            {row.subjectUser ? ` · patient: ${row.subjectUser.name}` : ''}
          </div>
        </div>
        <span className="muted audit-time">{fmt(row.createdAt)}</span>
      </button>

      {open && (
        <div className="audit-row-body">
          <div className="muted">
            {row.entityType}
            {row.entityId ? ` · ${row.entityId}` : ''}
            {entityPath && (
              <>
                {' · '}
                <Link href={`${entityPath}/${row.entityId}`}>Open record</Link>
              </>
            )}
          </div>
          {error && <div className="error-banner">{error}</div>}
          {!detail && !error && <p className="muted">Loading…</p>}
          {detail && (
            <div className="audit-diff">
              <div>
                <div className="audit-diff-label">Before</div>
                <pre>{detail.before == null ? '—' : JSON.stringify(detail.before, null, 2)}</pre>
              </div>
              <div>
                <div className="audit-diff-label">After</div>
                <pre>{detail.after == null ? '—' : JSON.stringify(detail.after, null, 2)}</pre>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
