/**
 * Phones are stored as typed (owner, 2026-10-31): sign-up and family
 * invitations take any 11-digit number, with no country code added and no
 * prefix check, like the seeded staff accounts. Accounts and invitations
 * from before that store the +880 form, so lookups try every spelling
 * ([phoneVariants]).
 */

/** Drops spaces, dashes, dots and brackets; nothing else changes. */
export function cleanPhone(raw: string): string {
  return raw.trim().replace(/[\s\-().]/g, '');
}

/**
 * The +<country code> form, used for the SMS gateway, throttle keys and to
 * find accounts stored that way: 01XXXXXXXXX becomes +8801XXXXXXXXX.
 */
export function normalizePhone(raw: string): string {
  let value = cleanPhone(raw);
  if (value.startsWith('00')) value = `+${value.slice(2)}`;
  if (/^01\d{9}$/.test(value)) return `+88${value}`;
  if (!value.startsWith('+')) value = `+${value}`;
  return value;
}

/**
 * Every stored spelling of one number: as typed, the +880 form, and the
 * local 01... form of a +880 number. "01712345678" and "+8801712345678"
 * are the same person.
 */
export function phoneVariants(raw: string): string[] {
  const typed = cleanPhone(raw);
  const normalized = normalizePhone(typed);
  const variants = [typed, normalized];
  if (/^\+8801\d{9}$/.test(normalized)) variants.push(normalized.slice(3));
  return [...new Set(variants)];
}
