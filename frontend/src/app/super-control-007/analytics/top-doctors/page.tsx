'use client';

import { listTopDoctors } from '@/lib/api-client';
import { RankedPage } from '@/components/ranked-page';
import { TopDoctorRows } from '@/components/analytics';

export default function TopDoctorsPage() {
  return (
    <RankedPage
      title="Doctors by patients"
      intro="Distinct patients on confirmed prescriptions (active or ended). Refreshed every few minutes."
      fetchPage={listTopDoctors}
      renderRows={(items) => <TopDoctorRows rows={items} ranks={items.map((d) => d.rank)} />}
    />
  );
}
