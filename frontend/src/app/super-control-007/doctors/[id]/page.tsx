'use client';

import { useParams } from 'next/navigation';
import { Doctor, getDoctor } from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { RecordView } from '@/components/record-view';
import { createdByLabel } from '@/components/created-by';

export default function AdminDoctorPage() {
  const { id } = useParams<{ id: string }>();
  return (
    <RecordView<Doctor>
      recordId={id}
      load={() => getDoctor(id)}
      title={(d) => d.name}
      backHref={`${ADMIN_BASE}/doctors`}
      backLabel="Doctors"
      incomplete={(d) => Boolean(d.incomplete)}
      rows={(d) => [
        ['Name', d.name],
        ['Specialty', d.specialty?.name],
        ['Phone', d.phone],
        ['Chamber / address', d.chamber],
        ['BMDC number (optional)', d.bmdcNumber],
        ['District (optional)', d.district?.name],
        ['Patients', d.patients ?? 0],
        ['Prescriptions', d._count?.prescriptions ?? 0],
        ['Created by', createdByLabel(d.createdBy)],
      ]}
    />
  );
}
