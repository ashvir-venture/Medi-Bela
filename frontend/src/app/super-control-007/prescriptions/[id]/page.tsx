'use client';

import { useParams } from 'next/navigation';
import { PrescriptionWorkspace } from '@/components/prescriptions/prescription-workspace';
import { ADMIN_BASE } from '@/lib/paths';

export default function AdminPrescriptionPage() {
  const { id } = useParams<{ id: string }>();
  return <PrescriptionWorkspace id={id} basePath={`${ADMIN_BASE}/prescriptions`} readOnly />;
}
