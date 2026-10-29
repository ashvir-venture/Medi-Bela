'use client';

import { useEffect, useState } from 'react';
import { ThemeChoice, applyThemeChoice, readThemeChoice } from '@/lib/theme';

const OPTIONS: { value: ThemeChoice; label: string }[] = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
];

/** System / Light / Dark, in the sidebar footer and on the login page. */
export function ThemeToggle() {
  // Read after mount: localStorage doesn't exist during server rendering.
  const [choice, setChoice] = useState<ThemeChoice | null>(null);
  useEffect(() => setChoice(readThemeChoice()), []);

  return (
    <div className="theme-toggle" role="radiogroup" aria-label="Theme">
      {OPTIONS.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={choice === o.value}
          className={choice === o.value ? 'active' : ''}
          onClick={() => {
            applyThemeChoice(o.value);
            setChoice(o.value);
          }}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
