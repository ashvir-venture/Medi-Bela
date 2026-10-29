'use client';

import { listTopMedicines } from '@/lib/api-client';
import { RankedPage } from '@/components/ranked-page';
import { TopMedicineRows } from '@/components/analytics';

export default function TopMedicinesPage() {
  return (
    <RankedPage
      title="Medicines by patients"
      intro="Distinct patients per catalog medicine on confirmed prescriptions (active or ended); self-added medicines are not counted. Refreshed every few minutes."
      fetchPage={listTopMedicines}
      renderRows={(items) => <TopMedicineRows rows={items} ranks={items.map((m) => m.rank)} />}
    />
  );
}
