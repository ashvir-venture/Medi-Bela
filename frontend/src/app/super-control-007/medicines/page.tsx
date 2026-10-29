'use client';

import { Suspense } from 'react';
import { CatalogMedicine, listMedicines } from '@/lib/api-client';
import { ADMIN_BASE } from '@/lib/paths';
import { CatalogList } from '@/components/catalog-list';
import { createdByLabel } from '@/components/created-by';

export default function AdminMedicinesPage() {
  return (
    // useSearchParams needs a Suspense boundary in the App Router.
    <Suspense>
      <CatalogList<CatalogMedicine>
        title="Medicines"
        intro="Read-only view. Pharmacists complete medicine records (form, category, manufacturer)."
        basePath={`${ADMIN_BASE}/medicines`}
        searchLabel="Search by brand name"
        incompleteLabel="Only incomplete"
        fetchPage={listMedicines}
        isIncomplete={(m) => Boolean(m.incomplete)}
        renderRow={(m) => (
          <>
            <div style={{ fontWeight: 600 }}>
              {m.brandName}
              {m.form && <span className="muted"> · {m.form.name}</span>}
            </div>
            <div className="muted">
              {[m.category?.name, m.manufacturer, m.genericName].filter(Boolean).join(' · ') || 'No details yet'}
              {m._count ? ` · on ${m._count.lines} prescription line(s)` : ''}
            </div>
            <div className="muted">Created by {createdByLabel(m.createdBy)}</div>
          </>
        )}
      />
    </Suspense>
  );
}
