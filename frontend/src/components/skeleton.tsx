/**
 * Grey placeholder shapes in the layout of the content that is loading,
 * with a gentle pulse (none when the computer asks for reduced motion).
 * Hidden from screen readers, which hear "Loading" once instead.
 */
export function Skeleton({ kind = 'table', rows = 5 }: { kind?: 'table' | 'detail' | 'dashboard' | 'page'; rows?: number }) {
  return (
    <div className={`skeleton skeleton-${kind}`} role="status" aria-label="Loading">
      {kind === 'dashboard' && (
        <div className="stat-grid" aria-hidden="true">
          {Array.from({ length: 4 }, (_, i) => (
            <div key={i} className="stat-card skeleton-card">
              <span className="sk sk-line sk-short" />
              <span className="sk sk-line sk-value" />
            </div>
          ))}
        </div>
      )}
      {(kind === 'table' || kind === 'dashboard') && (
        <div className="data-list" aria-hidden="true">
          <div className="data-head">
            <span className="sk sk-line sk-short" />
          </div>
          {Array.from({ length: rows }, (_, i) => (
            <div key={i} className="data-row skeleton-row">
              <span className="sk sk-line" />
              <span className="sk sk-line sk-short" />
              <span className="sk sk-pill" />
            </div>
          ))}
        </div>
      )}
      {(kind === 'detail' || kind === 'page') && (
        <div className="card" aria-hidden="true">
          <span className="sk sk-line sk-title" />
          {Array.from({ length: kind === 'page' ? 2 : rows }, (_, i) => (
            <span key={i} className={`sk sk-line ${i % 3 === 2 ? 'sk-short' : ''}`} />
          ))}
        </div>
      )}
    </div>
  );
}

/** A small spinner inside a button while its action runs (the button is disabled meanwhile). */
export function ButtonSpinner() {
  return <span className="btn-spinner" aria-hidden="true" />;
}
