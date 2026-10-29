'use client';

import { PrescriptionQueue } from '@/components/prescriptions/prescription-queue';

export default function PrescriptionsPage() {
  return (
    <PrescriptionQueue
      basePath="/prescriptions"
      intro="Open a prescription to fill in the doctor, visit, tests and medicines, then send it to the patient or reject it with feedback."
    />
  );
}
