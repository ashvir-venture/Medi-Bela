'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  AnalyticsData,
  ApiError,
  DivisionAnalytics,
  TopDoctor,
  TopMedicine,
  getAnalytics,
  getDivisionAnalytics,
} from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';

/**
 * The admin dashboard's analytics (GET /admin/analytics). Every number is
 * computed by the backend and cached there for a few minutes; this only renders.
 */
export function AnalyticsSection() {
  const [data, setData] = useState<AnalyticsData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getAnalytics()
      .then(setData)
      .catch((err) => setError(err instanceof ApiError ? err.message : 'Failed to load analytics'));
  }, []);

  if (error) return <div className="error-banner">{error}</div>;
  if (!data) return <p className="muted">Loading analytics…</p>;

  const { users } = data;
  return (
    <>
      {/* Total users and families are in the dashboard's top cards. */}
      <h3 className="section-title">Users ({users.total})</h3>
      <div className="stat-grid">
        <div className="stat-card">
          <div className="stat-value">{data.families.members}</div>
          <div className="muted">People in a family ({data.families.total} families)</div>
        </div>
      </div>

      <DivisionCard data={data} />

      <div className="analytics-grid">
        <div className="card">
          <h2>By gender</h2>
          <HBarList
            rows={[
              ...users.byGender.map((g) => ({ key: String(g.id), label: g.name, count: g.count })),
              ...notSetRow(users.genderNotSet),
            ]}
          />
        </div>
        <div className="card">
          <h2>By age</h2>
          <HBarList
            rows={[
              ...users.byAge.map((a) => ({ key: a.band, label: a.band, count: a.count })),
              ...notSetRow(users.ageNotSet),
            ]}
          />
        </div>
      </div>

      <h3 className="section-title">Doctors and medicines</h3>
      <div className="stat-grid">
        <Link href={`${ADMIN_BASE}/doctors`} className="stat-card">
          <div className="stat-value">{data.catalog.doctors}</div>
          <div className="muted">Doctors</div>
        </Link>
        <Link
          href={`${ADMIN_BASE}/doctors?incomplete=1`}
          className={`stat-card ${data.catalog.incompleteDoctors > 0 ? 'warn' : ''}`}
        >
          <div className="stat-value">{data.catalog.incompleteDoctors}</div>
          <div className="muted">Incomplete doctor records</div>
        </Link>
        <Link href={`${ADMIN_BASE}/medicines`} className="stat-card">
          <div className="stat-value">{data.catalog.medicines}</div>
          <div className="muted">Medicines</div>
        </Link>
        <Link
          href={`${ADMIN_BASE}/medicines?incomplete=1`}
          className={`stat-card ${data.catalog.incompleteMedicines > 0 ? 'warn' : ''}`}
        >
          <div className="stat-value">{data.catalog.incompleteMedicines}</div>
          <div className="muted">Incomplete medicine records</div>
        </Link>
      </div>

      <div className="analytics-grid">
        <div className="card">
          <div className="card-head" style={{ justifyContent: 'space-between' }}>
            <h2 style={{ marginBottom: 0 }}>Doctors with the most patients</h2>
            <Link href={`${ADMIN_BASE}/analytics/top-doctors`} className="btn btn-sm">
              See all
            </Link>
          </div>
          <TopDoctorRows rows={data.topDoctors} />
        </div>
        <div className="card">
          <div className="card-head" style={{ justifyContent: 'space-between' }}>
            <h2 style={{ marginBottom: 0 }}>Most-used medicines</h2>
            <Link href={`${ADMIN_BASE}/analytics/top-medicines`} className="btn btn-sm">
              See all
            </Link>
          </div>
          <TopMedicineRows rows={data.topMedicines} />
        </div>
      </div>
      <p className="muted" style={{ fontSize: 12 }}>
        Patients = distinct patients on confirmed prescriptions (active or ended). Analytics computed{' '}
        {new Date(data.generatedAt).toLocaleTimeString()}; they refresh every {Math.round(data.cacheSeconds / 60)}{' '}
        minutes.
      </p>
    </>
  );
}

function notSetRow(count: number) {
  return count > 0 ? [{ key: 'not-set', label: 'Not set', count, muted: true }] : [];
}

/** Users per division; a division opens its districts below. */
function DivisionCard({ data }: { data: AnalyticsData }) {
  const [openId, setOpenId] = useState<number | null>(null);
  const [division, setDivision] = useState<DivisionAnalytics | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (openId === null) return;
    let cancelled = false;
    setDivision(null);
    setError(null);
    getDivisionAnalytics(openId)
      .then((d) => !cancelled && setDivision(d))
      .catch((err) => !cancelled && setError(err instanceof ApiError ? err.message : 'Failed to load districts'));
    return () => {
      cancelled = true;
    };
  }, [openId]);

  return (
    <div className="card">
      <h2>By division</h2>
      <p className="muted" style={{ marginTop: -6 }}>
        Select a division to see its districts.
      </p>
      <HBarList
        rows={[
          ...data.users.byDivision.map((d) => ({
            key: String(d.id),
            label: d.name,
            count: d.count,
            active: d.id === openId,
            onClick: () => setOpenId(d.id === openId ? null : d.id),
          })),
          ...notSetRow(data.users.divisionNotSet),
        ]}
      />
      {openId !== null && (
        <div className="analytics-sub">
          {error && <div className="error-banner">{error}</div>}
          {!division ? (
            !error && <p className="muted">Loading districts…</p>
          ) : (
            <>
              <h2>Districts in {division.division.name}</h2>
              <HBarList
                rows={[
                  ...division.districts.map((d) => ({ key: String(d.id), label: d.name, count: d.count })),
                  ...notSetRow(division.notSet),
                ]}
              />
            </>
          )}
        </div>
      )}
    </div>
  );
}

interface HBarRow {
  key: string;
  label: string;
  count: number;
  muted?: boolean;
  active?: boolean;
  onClick?: () => void;
}

/** Horizontal bars, widths relative to the largest count. */
export function HBarList({ rows }: { rows: HBarRow[] }) {
  const max = Math.max(1, ...rows.map((r) => r.count));
  if (rows.length === 0) return <p className="muted">Nothing yet.</p>;
  return (
    <div className="hbars">
      {rows.map((r) => {
        const content = (
          <>
            <span className={`hbar-label ${r.muted ? 'muted' : ''}`}>{r.label}</span>
            <span className="hbar-track">
              <span className={`hbar ${r.count === 0 ? 'zero' : ''}`} style={{ width: `${(r.count / max) * 100}%` }} />
            </span>
            <span className="hbar-count">{r.count}</span>
          </>
        );
        return r.onClick ? (
          <button
            key={r.key}
            type="button"
            className={`hbar-row clickable ${r.active ? 'active' : ''}`}
            onClick={r.onClick}
            aria-expanded={r.active}
          >
            {content}
          </button>
        ) : (
          <div key={r.key} className="hbar-row">
            {content}
          </div>
        );
      })}
    </div>
  );
}

export function TopDoctorRows({ rows, ranks }: { rows: TopDoctor[]; ranks?: number[] }) {
  if (rows.length === 0) return <p className="muted">No confirmed prescriptions with a doctor yet.</p>;
  return (
    <>
      {rows.map((d, i) => (
        <Link key={d.id} href={`${ADMIN_BASE}/doctors/${d.id}`} className="list-item">
          <div>
            <div style={{ fontWeight: 600 }}>
              {ranks?.[i] ?? i + 1}. {d.name}
            </div>
            <span className="muted">{d.specialty?.name ?? 'Specialty not set'}</span>
          </div>
          <span className="muted">{d.patients} patient(s)</span>
        </Link>
      ))}
    </>
  );
}

export function TopMedicineRows({ rows, ranks }: { rows: TopMedicine[]; ranks?: number[] }) {
  if (rows.length === 0) return <p className="muted">No confirmed prescriptions with catalog medicines yet.</p>;
  return (
    <>
      {rows.map((m, i) => (
        <Link key={m.id} href={`${ADMIN_BASE}/medicines/${m.id}`} className="list-item">
          <div>
            <div style={{ fontWeight: 600 }}>
              {ranks?.[i] ?? i + 1}. {m.brandName}
              {m.form && <span className="muted"> · {m.form.name}</span>}
            </div>
            <span className="muted">{m.manufacturer ?? 'Manufacturer not set'}</span>
          </div>
          <span className="muted">{m.patients} patient(s)</span>
        </Link>
      ))}
    </>
  );
}
