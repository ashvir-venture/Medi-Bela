/**
 * Page heading inside the sidebar layout (navigation lives in AppShell).
 * Kept under its old name so every page keeps `<Topbar title=... />`.
 */
export function Topbar({ title, actions }: { title: string; actions?: React.ReactNode }) {
  return (
    <div className="page-header">
      <h1>{title}</h1>
      {actions && <div className="page-header-actions">{actions}</div>}
    </div>
  );
}
