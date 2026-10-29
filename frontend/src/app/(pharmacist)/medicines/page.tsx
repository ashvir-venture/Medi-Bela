'use client';

import { Suspense } from 'react';
import { CatalogMedicine, listMedicines } from '@/lib/api-client';
import { CatalogList } from '@/components/catalog-list';

export default function MedicinesPage() {
  return (
    // useSearchParams needs a Suspense boundary in the App Router.
    <Suspense>
      <CatalogList<CatalogMedicine>
        title="Medicines"
        intro="New medicines typed on a prescription land here with only a brand name. Add the form, category and manufacturer (e.g. Seclo - Tablet - Gastric - Square Pharma); the generic name is optional. Strength stays on each prescription line."
        basePath="/medicines"
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
              {[m.genericName, m.category?.name, m.manufacturer].filter(Boolean).join(' · ') ||
                'No details yet'}
              {m._count ? ` · on ${m._count.lines} prescription line(s)` : ''}
            </div>
          </>
        )}
      />
    </Suspense>
  );
}
