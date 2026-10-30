'use client';

import { useEffect, useId, useRef, useState } from 'react';

const DEBOUNCE_MS = 250;

/**
 * Text input with a suggestion list fetched as the user types (prefix
 * search on the backend). Typing never forces a pick: the parent decides
 * what free text means (e.g. "new medicine"). Arrow keys + Enter pick,
 * Escape closes.
 */
export function Autosuggest<T>({
  id,
  value,
  onChange,
  search,
  getKey,
  renderItem,
  onPick,
  placeholder,
  disabled,
  autoFocus,
}: {
  id?: string;
  value: string;
  onChange: (text: string) => void;
  search: (q: string) => Promise<T[]>;
  getKey: (item: T) => string;
  renderItem: (item: T) => React.ReactNode;
  onPick: (item: T) => void;
  placeholder?: string;
  disabled?: boolean;
  autoFocus?: boolean;
}) {
  const [items, setItems] = useState<T[]>([]);
  const [open, setOpen] = useState(false);
  // The suggestion list, named by the input's aria-controls.
  const fallbackId = useId();
  const listId = `${id ?? fallbackId}-list`;
  const [highlight, setHighlight] = useState(0);
  const [loading, setLoading] = useState(false);
  // Only search after the user typed, not when the parent sets a value.
  const typed = useRef(false);
  const searchRef = useRef(search);
  searchRef.current = search;

  useEffect(() => {
    if (!typed.current) return;
    const q = value.trim();
    if (!q) {
      setItems([]);
      setOpen(false);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(async () => {
      setLoading(true);
      try {
        const result = await searchRef.current(q);
        if (cancelled) return;
        setItems(result);
        setHighlight(0);
        setOpen(true);
      } catch {
        if (!cancelled) setItems([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }, DEBOUNCE_MS);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [value]);

  function pick(item: T) {
    typed.current = false;
    setOpen(false);
    onPick(item);
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (!open || items.length === 0) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setHighlight((h) => (h + 1) % items.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setHighlight((h) => (h - 1 + items.length) % items.length);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      pick(items[highlight]);
    } else if (e.key === 'Escape') {
      setOpen(false);
    }
  }

  return (
    <div className="autosuggest">
      <input
        id={id}
        className="input"
        value={value}
        placeholder={placeholder}
        disabled={disabled}
        autoFocus={autoFocus}
        autoComplete="off"
        role="combobox"
        aria-expanded={open}
        aria-controls={listId}
        aria-autocomplete="list"
        onChange={(e) => {
          typed.current = true;
          onChange(e.target.value);
        }}
        onKeyDown={onKeyDown}
        onFocus={() => items.length > 0 && typed.current && setOpen(true)}
        // Delay so a click on a suggestion lands before the list closes.
        onBlur={() => setTimeout(() => setOpen(false), 150)}
      />
      {loading && <span className="autosuggest-spinner" aria-hidden="true" />}
      {open && (
        <ul id={listId} className="autosuggest-list" role="listbox">
          {items.length === 0 ? (
            <li className="autosuggest-empty">No match. Keep typing to add it as new.</li>
          ) : (
            items.map((item, i) => (
              <li
                key={getKey(item)}
                role="option"
                aria-selected={i === highlight}
                className={i === highlight ? 'active' : ''}
                onMouseDown={(e) => {
                  e.preventDefault();
                  pick(item);
                }}
                onMouseEnter={() => setHighlight(i)}
              >
                {renderItem(item)}
              </li>
            ))
          )}
        </ul>
      )}
    </div>
  );
}
