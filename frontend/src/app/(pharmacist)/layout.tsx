'use client';

import { AppShell, PHARMACIST_NAV, ShellGate } from '@/components/app-shell';
import { useRequireRole } from '@/lib/use-require-auth';

/** Every pharmacist page renders inside this gate and sidebar. */
export default function PharmacistLayout({ children }: { children: React.ReactNode }) {
  const { user, error, retry } = useRequireRole('PHARMACIST');
  if (!user) return <ShellGate error={error} onRetry={retry} />;
  return (
    <AppShell user={user} nav={PHARMACIST_NAV}>
      {children}
    </AppShell>
  );
}
