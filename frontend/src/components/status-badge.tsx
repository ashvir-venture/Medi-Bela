import type { PrescriptionStatus } from '@/lib/api-client';

const LABELS: Record<PrescriptionStatus, string> = {
  PENDING: 'PENDING',
  REJECTED: 'REJECTED',
  AWAITING_CONFIRMATION: 'AWAITING CONFIRMATION',
  ACTIVE: 'ACTIVE',
  ENDED: 'ENDED',
};

export function StatusBadge({ status }: { status: PrescriptionStatus }) {
  const className =
    status === 'ACTIVE' || status === 'ENDED'
      ? 'badge badge-completed'
      : status === 'REJECTED'
        ? 'badge badge-rejected'
        : 'badge badge-pending';
  return <span className={className}>{LABELS[status] ?? status}</span>;
}
