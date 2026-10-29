'use client';

import { useParams } from 'next/navigation';
import { CatalogMedicine, getMedicine } from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { RecordView } from '@/components/record-view';
import { createdByLabel } from '@/components/created-by';

export default function AdminMedicinePage() {
  const { id } = useParams<{ id: string }>();
  return (
    <RecordView<CatalogMedicine>
      recordId={id}
      load={() => getMedicine(id)}
      title={(m) => m.brandName}
      backHref={`${ADMIN_BASE}/medicines`}
      backLabel="Medicines"
      incomplete={(m) => Boolean(m.incomplete)}
      rows={(m) => [
        ['Brand name', m.brandName],
        ['Form', m.form?.name],
        ['Category', m.category?.name],
        ['Manufacturer', m.manufacturer],
        ['Generic name (optional)', m.genericName],
        ['Patients', m.patients ?? 0],
        ['Prescription lines', m._count?.lines ?? 0],
        ['Created by', createdByLabel(m.createdBy)],
      ]}
    />
  );
}
