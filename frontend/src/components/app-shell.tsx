'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { AdminUser, clearTokens } from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { Icon, IconName } from '@/components/icons';

export interface NavItem {
  href: string;
  label: string;
  icon: IconName;
}

export const PHARMACIST_NAV: NavItem[] = [
  { href: '/dashboard', label: 'Dashboard', icon: 'dashboard' },
  { href: '/prescriptions', label: 'Prescriptions', icon: 'prescription' },
  { href: '/doctors', label: 'Doctors', icon: 'doctor' },
  { href: '/medicines', label: 'Medicines', icon: 'medicine' },
  { href: '/health-rules', label: 'Health rules', icon: 'rule' },
  { href: '/notices', label: 'Notices', icon: 'notice' },
];

export const ADMIN_NAV: NavItem[] = [
  { href: `${ADMIN_BASE}/dashboard`, label: 'Dashboard', icon: 'dashboard' },
  { href: `${ADMIN_BASE}/prescriptions`, label: 'Prescriptions', icon: 'prescription' },
  { href: `${ADMIN_BASE}/doctors`, label: 'Doctors', icon: 'doctor' },
  { href: `${ADMIN_BASE}/medicines`, label: 'Medicines', icon: 'medicine' },
  { href: `${ADMIN_BASE}/routines`, label: 'Routines', icon: 'routine' },
  { href: `${ADMIN_BASE}/health-suggestions`, label: 'AI suggestions', icon: 'sparkle' },
  { href: `${ADMIN_BASE}/notices`, label: 'Notices', icon: 'notice' },
];

const ROLE_LABEL: Record<AdminUser['role'], string> = {
  ADMIN: 'Admin',
  PHARMACIST: 'Pharmacist',
  USER: 'User',
};

function isActive(pathname: string, href: string) {
  return pathname === href || pathname.startsWith(`${href}/`);
}

/** Left sidebar on wide screens; a slide-in drawer behind a menu button on phones. */
export function AppShell({
  user,
  nav,
  children,
}: {
  user: AdminUser;
  nav: NavItem[];
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);

  // Close the drawer after navigating.
  useEffect(() => setOpen(false), [pathname]);

  function logout() {
    clearTokens();
    router.replace('/login');
  }

  return (
    <div className={`shell ${open ? 'shell-open' : ''}`}>
      <header className="shell-mobilebar">
        <button className="icon-btn" aria-label="Open menu" onClick={() => setOpen(true)}>
          <Icon name="menu" size={22} />
        </button>
        <span className="shell-brand-text">Medi-Bela</span>
      </header>

      <div className="shell-backdrop" onClick={() => setOpen(false)} aria-hidden="true" />

      <aside className="sidebar" aria-label="Main navigation">
        <div className="sidebar-brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logoEn.png"
            alt=""
            className="sidebar-logo"
            onError={(e) => {
              e.currentTarget.style.display = 'none';
            }}
          />
          <span className="shell-brand-text">Medi-Bela</span>
          <button className="icon-btn sidebar-close" aria-label="Close menu" onClick={() => setOpen(false)}>
            <Icon name="close" size={20} />
          </button>
        </div>

        <nav className="sidebar-nav">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={`sidebar-link ${isActive(pathname, item.href) ? 'active' : ''}`}
            >
              <Icon name={item.icon} />
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="sidebar-user">
            <div className="sidebar-user-name">{user.name}</div>
            <div className="muted">{ROLE_LABEL[user.role]}</div>
          </div>
          <button className="btn btn-block" onClick={logout}>
            <Icon name="logout" /> Log out
          </button>
        </div>
      </aside>

      <main className="shell-main">{children}</main>
    </div>
  );
}

/** Shown while a layout checks the session. */
export function ShellGate({ error, onRetry }: { error: string | null; onRetry: () => void }) {
  return (
    <div className="login-wrapper">
      {error ? (
        <div className="card" style={{ maxWidth: 360 }}>
          <div className="error-banner">{error}</div>
          <button className="btn btn-primary" onClick={onRetry}>
            Try again
          </button>
        </div>
      ) : (
        <p className="muted">Loading…</p>
      )}
    </div>
  );
}
