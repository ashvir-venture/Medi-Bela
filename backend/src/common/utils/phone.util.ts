/**
 * Canonical phone format used EVERYWHERE a phone number is stored or
 * compared: `+<country code><number>`, digits only after the plus.
 *
 * Phone number is the family-invitation identity, so "+8801712345678",
 * "8801712345678", "01712345678" and "+880 1712-345678" must all resolve
 * to the same user. Without a single canonical form an invitation sent to
 * one spelling is silently invisible to an account registered with another.
 *
 * Bangladesh local format (01XXXXXXXXX) is expanded to +8801XXXXXXXXX since
 * that is how users naturally type their number.
 */
export function normalizePhone(raw: string): string {
  let value = raw.trim().replace(/[\s\-().]/g, '');
  if (value.startsWith('00')) value = `+${value.slice(2)}`;
  if (/^01\d{9}$/.test(value)) return `+88${value}`;
  if (!value.startsWith('+')) value = `+${value}`;
  return value;
}
