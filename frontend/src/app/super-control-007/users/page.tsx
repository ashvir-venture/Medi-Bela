'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import {
  AccountStatus,
  AdminUser,
  AdminUserRow,
  AgeBand,
  ApiError,
  LookupRow,
  banUser,
  getLookups,
  listAdminUsers,
  unbanUser,
} from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { Pager, useCursorPager } from '@/components/pager';
import { DataList } from '@/components/data-list';
import { useToast } from '@/components/toast';
import { ButtonSpinner, Skeleton } from '@/components/skeleton';
import { EmptyState } from '@/components/empty-state';

const ROLE_LABEL: Record<AdminUser['role'], string> = {
  USER: 'Patient',
  PHARMACIST: 'Pharmacist',
  ADMIN: 'Admin',
};

const STATUS: Record<AccountStatus, { label: string; badge: string }> = {
  ACTIVE: { label: 'Active', badge: 'badge-completed' },
  DEACTIVATED: { label: 'Deactivated', badge: 'badge-draft' },
  SUSPENDED: { label: 'Suspended', badge: 'badge-rejected' },
  DELETED: { label: 'Deleted', badge: 'badge-expired' },
};

const AGE_BANDS: AgeBand[] = ['0-17', '18-39', '40-59', '60+'];

export default function AdminUsersPage() {
  return (
    // useSearchParams needs a Suspense boundary in the App Router.
    <Suspense>
      <UsersList />
    </Suspense>
  );
}

/** Everyone with an account, 20 per page, newest first; admins ban and unban here. */
function UsersList() {
  const searchParams = useSearchParams();
  const [divisions, setDivisions] = useState<LookupRow[]>([]);
  const [phone, setPhone] = useState('');
  const [debouncedPhone, setDebouncedPhone] = useState('');
  const [divisionId, setDivisionId] = useState('');
  const [ageBand, setAgeBand] = useState('');
  const [role, setRole] = useState('');
  // The dashboard's status cards open this page with ?status=.
  const [status, setStatus] = useState(searchParams.get('status') ?? '');
  const [busyId, setBusyId] = useState<string | null>(null);
  const toast = useToast();

  useEffect(() => {
    getLookups()
      .then((l) => setDivisions(l.divisions))
      .catch(() => undefined); // the filter is optional; the list still works
  }, []);

  useEffect(() => {
    const t = setTimeout(() => setDebouncedPhone(phone.trim()), 300);
    return () => clearTimeout(t);
  }, [phone]);

  const pager = useCursorPager(
    (cursor) =>
      listAdminUsers({
        cursor,
        phone: debouncedPhone || undefined,
        divisionId: divisionId ? Number(divisionId) : undefined,
        ageBand: (ageBand || undefined) as AgeBand | undefined,
        role: (role || undefined) as AdminUser['role'] | undefined,
        status: (status || undefined) as AccountStatus | undefined,
      }),
    `${debouncedPhone}|${divisionId}|${ageBand}|${role}|${status}`,
  );

  async function toggleBan(u: AdminUserRow) {
    const banning = u.accountStatus !== 'SUSPENDED';
    const question = banning
      ? `Ban ${u.name}? They are signed out everywhere and can't sign in until you unban them.`
      : `Unban ${u.name}? They can sign in again.`;
    if (!confirm(question)) return;
    setBusyId(u.id);
    try {
      if (banning) await banUser(u.id);
      else await unbanUser(u.id);
      toast.success(banning ? `${u.name} is banned.` : `${u.name} is unbanned.`);
      pager.reload();
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : 'Could not change this account. Try again.');
    } finally {
      setBusyId(null);
    }
  }

  function clear() {
    setPhone('');
    setDivisionId('');
    setAgeBand('');
    setRole('');
    setStatus('');
  }

  return (
    <>
      <Topbar title="Users" subtitle="Patients, pharmacists and admins. Admin accounts can't be banned." />
      <div className="page">
        <div className="filter-bar">
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="user-phone">Phone (01…, +8801… or part)</label>
            <input
              id="user-phone"
              className="input"
              inputMode="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
          </div>
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="user-division">Division</label>
            <select id="user-division" className="input" value={divisionId} onChange={(e) => setDivisionId(e.target.value)}>
              <option value="">All</option>
              {divisions.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </select>
          </div>
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="user-age">Age</label>
            <select id="user-age" className="input" value={ageBand} onChange={(e) => setAgeBand(e.target.value)}>
              <option value="">All</option>
              {AGE_BANDS.map((b) => (
                <option key={b} value={b}>
                  {b}
                </option>
              ))}
            </select>
          </div>
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="user-role">Role</label>
            <select id="user-role" className="input" value={role} onChange={(e) => setRole(e.target.value)}>
              <option value="">All</option>
              <option value="USER">Patient</option>
              <option value="PHARMACIST">Pharmacist</option>
              <option value="ADMIN">Admin</option>
            </select>
          </div>
          <div className="field" style={{ marginBottom: 0 }}>
            <label htmlFor="user-status">Status</label>
            <select id="user-status" className="input" value={status} onChange={(e) => setStatus(e.target.value)}>
              <option value="">Active, deactivated and suspended</option>
              <option value="ACTIVE">Active</option>
              <option value="DEACTIVATED">Deactivated</option>
              <option value="SUSPENDED">Suspended</option>
              <option value="DELETED">Deleted</option>
            </select>
          </div>
          <button className="btn" onClick={clear}>
            Clear
          </button>
        </div>

        {pager.error && (
          <div className="error-banner">
            {pager.error}{' '}
            <button className="btn btn-sm" onClick={pager.reload}>
              Retry
            </button>
          </div>
        )}

        {pager.isLoading && pager.items.length === 0 ? (
          <Skeleton kind="table" />
        ) : pager.items.length === 0 ? (
          <EmptyState icon="users" message="No users match these filters." />
        ) : (
          <DataList<AdminUserRow>
            rows={pager.items}
            rowKey={(u) => u.id}
            minWidth={760}
            columns={[
              { label: 'Name', width: '1.6fr', render: (u) => <strong>{u.name}</strong> },
              { label: 'Phone', width: '1.3fr', render: (u) => u.phone ?? '—' },
              { label: 'Role', width: '1fr', render: (u) => ROLE_LABEL[u.role] },
              { label: 'Division', width: '1fr', render: (u) => u.division?.name ?? 'Not set' },
              {
                label: 'Status',
                width: '1fr',
                render: (u) => <span className={`badge ${STATUS[u.accountStatus].badge}`}>{STATUS[u.accountStatus].label}</span>,
              },
              {
                label: 'Action',
                width: '110px',
                end: true,
                render: (u) =>
                  u.canBan ? (
                    <button
                      className={`btn btn-sm ${u.accountStatus === 'SUSPENDED' ? '' : 'btn-danger'}`}
                      disabled={busyId === u.id}
                      onClick={() => toggleBan(u)}
                    >
                      {busyId === u.id ? <ButtonSpinner /> : u.accountStatus === 'SUSPENDED' ? 'Unban' : 'Ban'}
                    </button>
                  ) : (
                    <span className="muted">—</span>
                  ),
              },
            ]}
          />
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
