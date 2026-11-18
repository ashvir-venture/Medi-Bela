/**
 * The colour Android tints a push with, per kind (owner 2026-11-18): the same
 * table as the app's widgets/notification_tone.dart (medicine navy, family
 * alert amber, urgent red, caregiver's change teal, prescription green,
 * notice / test violet). Only a colour: no health data.
 */
const BY_KIND: Record<string, string> = {
  reading_alert: '#B3261E',
  help_alert: '#B3261E',
  caregiver_action: '#0E7C86',
  caregiver_changed: '#0E7C86',
  caregiver_permission: '#0E7C86',
  family_removed: '#0E7C86',
  medicine_box_empty: '#B85A10',
  test_pending: '#B85A10',
  as_needed_over_max: '#B85A10',
  personal_reminder_later: '#B85A10',
  notice_shared: '#4A3D80',
  member_prescription_ready: '#2F7A3A',
};

const BY_TYPE: Record<string, string> = {
  MEDICINE_REMINDER: '#143D6B',
  MISSED_DOSE_FAMILY_ALERT: '#B85A10',
  PRESCRIPTION_UPDATE: '#2F7A3A',
  NOTICE: '#4A3D80',
};

export const DEFAULT_NOTIFICATION_COLOR = '#0E7C86';

export function notificationColor(type: string, data?: Record<string, unknown> | null): string {
  const kind = typeof data?.kind === 'string' ? data.kind : undefined;
  return (kind && BY_KIND[kind]) || BY_TYPE[type] || DEFAULT_NOTIFICATION_COLOR;
}
