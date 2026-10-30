'use client';

import { useEffect, useState } from 'react';
import { ThemeChoice, applyThemeChoice, readThemeChoice } from '@/lib/theme';
import { Icon, IconName } from '@/components/icons';

const OPTIONS: { value: ThemeChoice; label: string; icon: IconName }[] = [
  { value: 'system', label: 'System', icon: 'system' },
  { value: 'light', label: 'Light', icon: 'sun' },
  { value: 'dark', label: 'Dark', icon: 'moon' },
];

/** System / Light / Dark with icons, top-right of the login page and every page header. */
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
          title={o.label}
          className={choice === o.value ? 'active' : ''}
          onClick={() => {
            applyThemeChoice(o.value);
            setChoice(o.value);
          }}
        >
          <Icon name={o.icon} size={16} />
          <span className="theme-toggle-label">{o.label}</span>
        </button>
      ))}
    </div>
  );
}
