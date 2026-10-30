'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { AdminUser, clearTokens, getDashboard, getPharmacistDashboard } from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { Icon, IconName } from '@/components/icons';
import { Skeleton } from '@/components/skeleton';

type BadgeKey = 'prescriptions' | 'suggestions' | 'notices';

export interface NavItem {
  href: string;
  label: string;
  icon: IconName;
  badge?: BadgeKey;
}

interface NavSection {
  label: string;
  items: NavItem[];
}

export type Area = 'PHARMACIST' | 'ADMIN';

const NAV: Record<Area, NavSection[]> = {
  PHARMACIST: [
    {
      label: 'Work',
      items: [
        { href: '/dashboard', label: 'Dashboard', icon: 'dashboard' },
        { href: '/prescriptions', label: 'Prescriptions', icon: 'prescription', badge: 'prescriptions' },
        { href: '/routines', label: 'Routines', icon: 'routine' },
        { href: '/health-suggestions', label: 'AI suggestions', icon: 'sparkle', badge: 'suggestions' },
        { href: '/notices', label: 'Notices', icon: 'notice', badge: 'notices' },
      ],
    },
    {
      label: 'Catalog',
      items: [
        { href: '/doctors', label: 'Doctors', icon: 'doctor' },
        { href: '/medicines', label: 'Medicines', icon: 'medicine' },
        { href: '/health-rules', label: 'Health rules', icon: 'rule' },
      ],
    },
    { label: 'Help', items: [{ href: '/support', label: 'Support', icon: 'help' }] },
  ],
  ADMIN: [
    { label: 'Overview', items: [{ href: `${ADMIN_BASE}/dashboard`, label: 'Dashboard', icon: 'dashboard' }] },
    { label: 'Content', items: [{ href: `${ADMIN_BASE}/notices`, label: 'Notices', icon: 'notice', badge: 'notices' }] },
    {
      label: 'Records',
      items: [
        { href: `${ADMIN_BASE}/doctors`, label: 'Doctors', icon: 'doctor' },
        { href: `${ADMIN_BASE}/medicines`, label: 'Medicines', icon: 'medicine' },
      ],
    },
    {
      label: 'Admin',
      items: [
        { href: `${ADMIN_BASE}/users`, label: 'Users', icon: 'users' },
        { href: `${ADMIN_BASE}/audit-log`, label: 'Audit log', icon: 'audit' },
      ],
    },
    { label: 'Help', items: [{ href: '/support', label: 'Support', icon: 'help' }] },
  ],
};

const CAPTION: Record<Area, string> = {
  PHARMACIST: 'Pharmacist workspace',
  ADMIN: 'Admin workspace',
};

const ROLE_LABEL: Record<AdminUser['role'], string> = {
  ADMIN: 'Admin',
  PHARMACIST: 'Pharmacist',
  USER: 'User',
};

/** A count, and whether it needs attention (amber) rather than just work waiting (teal). */
type Badge = { count: number; warn?: boolean };
type Badges = Partial<Record<BadgeKey, Badge>>;

/** Sidebar counts from the area's dashboard endpoint. */
async function loadBadges(area: Area): Promise<Badges> {
  if (area === 'PHARMACIST') {
    const d = await getPharmacistDashboard();
    return {
      prescriptions: { count: d.queue.pending },
      suggestions: { count: d.aiSuggestions.drafts },
      // Sent back by an admin needs the pharmacist; otherwise what waits for approval.
      notices: d.notices.sentBack > 0 ? { count: d.notices.sentBack, warn: true } : { count: d.notices.pending },
    };
  }
  const d = await getDashboard();
  return { notices: { count: d.analytics.noticesAwaitingApproval, warn: true } };
}

function isActive(pathname: string, href: string) {
  return pathname === href || pathname.startsWith(`${href}/`);
}

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return ((parts[0]?.[0] ?? '') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase() || '?';
}

/** Left sidebar on wide screens; a slide-in drawer behind a menu button on phones. */
export function AppShell({ user, area, children }: { user: AdminUser; area: Area; children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [badges, setBadges] = useState<Badges>({});

  // Close the drawer after navigating.
  useEffect(() => setOpen(false), [pathname]);

  // Once per page load; the counts are a hint, the pages show the real lists.
  useEffect(() => {
    loadBadges(area)
      .then(setBadges)
      .catch(() => undefined);
  }, [area]);

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
        <Brand caption={CAPTION[area]} />
      </header>

      <div className="shell-backdrop" onClick={() => setOpen(false)} aria-hidden="true" />

      <aside className="sidebar" aria-label="Main navigation">
        <div className="sidebar-brand">
          <Brand caption={CAPTION[area]} />
          <button className="icon-btn sidebar-close" aria-label="Close menu" onClick={() => setOpen(false)}>
            <Icon name="close" size={20} />
          </button>
        </div>

        <nav className="sidebar-nav">
          {NAV[area].map((section) => (
            <div key={section.label} className="sidebar-section">
              <div className="sidebar-section-label">{section.label}</div>
              {section.items.map((item) => {
                const badge = item.badge ? badges[item.badge] : undefined;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`sidebar-link ${isActive(pathname, item.href) ? 'active' : ''}`}
                  >
                    <Icon name={item.icon} />
                    <span className="sidebar-link-label">{item.label}</span>
                    {badge && badge.count > 0 && (
                      <span className={`nav-badge ${badge.warn ? 'nav-badge-warn' : ''}`}>{badge.count}</span>
                    )}
                  </Link>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="sidebar-user">
            <span className="avatar" aria-hidden="true">
              {initials(user.name)}
            </span>
            <div>
              <div className="sidebar-user-name">{user.name}</div>
              <div className="muted">{ROLE_LABEL[user.role]}</div>
            </div>
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

/** Icon mark + wordmark, top of the sidebar and the phone bar. */
function Brand({ caption }: { caption: string }) {
  return (
    <span className="brand">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/logo-mark.png" alt="" className="brand-mark" />
      <span className="brand-text">
        <span className="brand-name">
          Medi<span className="brand-accent">-Bela</span>
        </span>
        <span className="brand-caption">{caption}</span>
      </span>
    </span>
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
        <Skeleton kind="page" />
      )}
    </div>
  );
}
