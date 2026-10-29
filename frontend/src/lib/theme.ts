/**
 * Panel theme: 'system' follows the computer's light/dark setting; 'light' and
 * 'dark' force one by setting data-theme on <html> (see globals.css). The
 * choice is remembered in this browser only.
 */
export type ThemeChoice = 'system' | 'light' | 'dark';

export const THEME_KEY = 'medi_bela_theme';

/**
 * Runs in <head> before the page paints, so a forced theme never flashes the
 * other one first. Kept as a string because it must run before React loads.
 */
export const THEME_BOOT_SCRIPT = `try{var t=localStorage.getItem('${THEME_KEY}');if(t==='light'||t==='dark')document.documentElement.setAttribute('data-theme',t)}catch(e){}`;

export function readThemeChoice(): ThemeChoice {
  try {
    const t = localStorage.getItem(THEME_KEY);
    return t === 'light' || t === 'dark' ? t : 'system';
  } catch {
    return 'system';
  }
}

export function applyThemeChoice(choice: ThemeChoice) {
  const root = document.documentElement;
  if (choice === 'system') root.removeAttribute('data-theme');
  else root.setAttribute('data-theme', choice);
  try {
    if (choice === 'system') localStorage.removeItem(THEME_KEY);
    else localStorage.setItem(THEME_KEY, choice);
  } catch {
    // Storage blocked: the choice still applies until the page reloads.
  }
}
