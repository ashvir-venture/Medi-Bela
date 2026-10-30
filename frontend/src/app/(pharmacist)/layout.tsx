'use client';

import { AppShell, ShellGate } from '@/components/app-shell';
import { useRequireRole } from '@/lib/use-require-auth';

/** Every pharmacist page renders inside this gate and sidebar. */
export default function PharmacistLayout({ children }: { children: React.ReactNode }) {
  const { user, error, retry } = useRequireRole('PHARMACIST');
  if (!user) return <ShellGate error={error} onRetry={retry} />;
  return (
    <AppShell user={user} area="PHARMACIST">
      {children}
    </AppShell>
  );
}
