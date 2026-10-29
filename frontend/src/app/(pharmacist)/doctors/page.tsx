'use client';

import { Suspense } from 'react';
import { Doctor, listDoctors } from '@/lib/api-client';
import { CatalogList } from '@/components/catalog-list';

export default function DoctorsPage() {
  return (
    // useSearchParams needs a Suspense boundary in the App Router.
    <Suspense>
      <CatalogList<Doctor>
        title="Doctors"
        intro="Doctors are added from prescriptions. Complete their specialty, phone and chamber / address here; the BMDC number is optional but helps recognise the same doctor next time."
        basePath="/doctors"
        searchLabel="Search by name"
        incompleteLabel="Only incomplete"
        fetchPage={listDoctors}
        isIncomplete={(d) => Boolean(d.incomplete)}
        renderRow={(d) => (
          <>
            <div style={{ fontWeight: 600 }}>{d.name}</div>
            <div className="muted">
              {[d.specialty?.name, d.bmdcNumber && `BMDC ${d.bmdcNumber}`, d.district?.name]
                .filter(Boolean)
                .join(' · ') || 'No details yet'}
              {d._count ? ` · ${d._count.prescriptions} prescription(s)` : ''}
            </div>
          </>
        )}
      />
    </Suspense>
  );
}
