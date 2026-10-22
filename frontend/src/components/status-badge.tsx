export function StatusBadge({ status }: { status: 'PENDING' | 'COMPLETED' | 'REJECTED' }) {
  const className =
    status === 'COMPLETED'
      ? 'badge badge-completed'
      : status === 'REJECTED'
        ? 'badge badge-rejected'
        : 'badge badge-pending';
  return <span className={className}>{status}</span>;
}
