'use client';

import { useParams } from 'next/navigation';
import { PrescriptionWorkspace } from '@/components/prescriptions/prescription-workspace';
import { ADMIN_BASE } from '@/lib/paths';

export default function AdminPrescriptionPage() {
  const { id } = useParams<{ id: string }>();
  // Reached only from an audit-log entry's "Open record" (no admin prescription list).
  return (
    <PrescriptionWorkspace
      id={id}
      basePath={`${ADMIN_BASE}/prescriptions`}
      readOnly
      back={{ href: `${ADMIN_BASE}/audit-log`, label: 'Audit log' }}
    />
  );
}
