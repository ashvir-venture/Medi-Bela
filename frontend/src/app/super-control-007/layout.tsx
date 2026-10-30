'use client';

import { AppShell, ShellGate } from '@/components/app-shell';
import { useRequireRole } from '@/lib/use-require-auth';

/** Every admin page renders inside this gate and sidebar. */
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user, error, retry } = useRequireRole('ADMIN');
  if (!user) return <ShellGate error={error} onRetry={retry} />;
  return (
    <AppShell user={user} area="ADMIN">
      {children}
    </AppShell>
  );
}
