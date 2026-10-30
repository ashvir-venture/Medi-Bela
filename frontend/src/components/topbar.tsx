import { ThemeToggle } from '@/components/theme-toggle';

/**
 * Page heading inside the sidebar layout (navigation lives in AppShell),
 * with the theme switch in the right corner.
 * Kept under its old name so every page keeps `<Topbar title=... />`.
 */
export function Topbar({
  title,
  subtitle,
  actions,
}: {
  title: string;
  /** One line under the title. */
  subtitle?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="page-header">
      <div className="page-header-text">
        <h1>{title}</h1>
        {subtitle && <p className="page-subtitle">{subtitle}</p>}
      </div>
      <div className="page-header-actions">
        {actions}
        <ThemeToggle />
      </div>
    </div>
  );
}
