'use client';

import { useParams } from 'next/navigation';
import { PrescriptionWorkspace } from '@/components/prescriptions/prescription-workspace';

export default function PrescriptionPage() {
  const { id } = useParams<{ id: string }>();
  return <PrescriptionWorkspace id={id} basePath="/prescriptions" readOnly={false} />;
}
