import Link from 'next/link';

export interface Column<T> {
  label: string;
  /** CSS grid track, e.g. "2fr" or "140px". Default 1fr. */
  width?: string;
  render: (row: T) => React.ReactNode;
  /** Right-aligned (actions, numbers). */
  end?: boolean;
}

/**
 * A list as a table on wide screens (uppercase headers, row hover, status
 * pills) that turns into stacked cards under 640px, each value with its
 * column label. Rows are links when `rowHref` is given, so behavior stays
 * the same as the old list items. Wide tables scroll inside their box.
 */
export function DataList<T>({
  rows,
  columns,
  rowKey,
  rowHref,
  minWidth = 640,
}: {
  rows: T[];
  columns: Column<T>[];
  rowKey: (row: T) => string;
  rowHref?: (row: T) => string;
  /** Below this width the table scrolls (wide screens) instead of squeezing. */
  minWidth?: number;
}) {
  const template = columns.map((c) => c.width ?? '1fr').join(' ');
  const style = { gridTemplateColumns: template, minWidth } as React.CSSProperties;

  return (
    <div className="data-list" role="table">
      <div className="data-scroll">
        <div className="data-head" role="row" style={style}>
          {columns.map((c) => (
            <div key={c.label} role="columnheader" className={c.end ? 'data-end' : undefined}>
              {c.label}
            </div>
          ))}
        </div>
        {rows.map((row) => {
          const cells = columns.map((c) => (
            <div key={c.label} role="cell" data-label={c.label} className={`data-cell ${c.end ? 'data-end' : ''}`}>
              {c.render(row)}
            </div>
          ));
          const href = rowHref?.(row);
          return href ? (
            <Link key={rowKey(row)} href={href} className="data-row data-row-link" role="row" style={style}>
              {cells}
            </Link>
          ) : (
            <div key={rowKey(row)} className="data-row" role="row" style={style}>
              {cells}
            </div>
          );
        })}
      </div>
    </div>
  );
}
