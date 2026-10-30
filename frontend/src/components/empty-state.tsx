import { Icon, IconName } from '@/components/icons';

/** A line icon, one line of text, and the next action when there is one. */
export function EmptyState({
  icon,
  message,
  action,
}: {
  icon: IconName;
  message: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="empty-state">
      <span className="empty-icon">
        <Icon name={icon} size={28} />
      </span>
      <p>{message}</p>
      {action}
    </div>
  );
}
