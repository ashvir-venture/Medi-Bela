import type { AdminUser } from '@/lib/api-client';

/** The admin area lives under this unlisted path; pharmacists use the root. */
export const ADMIN_BASE = '/super-control-007';

export type StaffRole = Extract<AdminUser['role'], 'ADMIN' | 'PHARMACIST'>;

export function isStaffRole(role: AdminUser['role']): role is StaffRole {
  return role === 'ADMIN' || role === 'PHARMACIST';
}

/** Where each role lands after login. */
export function homeFor(role: StaffRole): string {
  return role === 'ADMIN' ? `${ADMIN_BASE}/dashboard` : '/dashboard';
}
