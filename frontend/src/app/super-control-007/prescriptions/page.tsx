'use client';

import { PrescriptionQueue } from '@/components/prescriptions/prescription-queue';
import { ADMIN_BASE } from '@/lib/paths';

export default function AdminPrescriptionsPage() {
  return (
    <PrescriptionQueue
      basePath={`${ADMIN_BASE}/prescriptions`}
      intro="Read-only view. Pharmacists prepare and reject prescriptions."
    />
  );
}
