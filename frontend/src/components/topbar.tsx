import { ThemeToggle } from '@/components/theme-toggle';

/**
 * Page heading inside the sidebar layout (navigation lives in AppShell),
 * with the theme switch in the right corner.
 * Kept under its old name so every page keeps `<Topbar title=... />`.
 */
export function Topbar({ title, actions }: { title: string; actions?: React.ReactNode }) {
  return (
    <div className="page-header">
      <h1>{title}</h1>
      <div className="page-header-actions">
        {actions}
        <ThemeToggle />
      </div>
    </div>
  );
}
