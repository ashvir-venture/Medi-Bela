'use client';

import { Suspense } from 'react';
import { Doctor, listDoctors } from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { CatalogList } from '@/components/catalog-list';
import { createdByLabel } from '@/components/created-by';

export default function AdminDoctorsPage() {
  return (
    // useSearchParams needs a Suspense boundary in the App Router.
    <Suspense>
      <CatalogList<Doctor>
        title="Doctors"
        intro="Read-only view. Pharmacists complete doctor records (specialty, phone, chamber / address)."
        basePath={`${ADMIN_BASE}/doctors`}
        searchLabel="Search by name"
        incompleteLabel="Only incomplete"
        fetchPage={listDoctors}
        isIncomplete={(d) => Boolean(d.incomplete)}
        renderRow={(d) => (
          <>
            <div style={{ fontWeight: 600 }}>{d.name}</div>
            <div className="muted">
              {[d.specialty?.name, d.chamber].filter(Boolean).join(' · ') || 'No details yet'}
              {d._count ? ` · ${d._count.prescriptions} prescription(s)` : ''}
            </div>
            <div className="muted">Created by {createdByLabel(d.createdBy)}</div>
          </>
        )}
      />
    </Suspense>
  );
}
