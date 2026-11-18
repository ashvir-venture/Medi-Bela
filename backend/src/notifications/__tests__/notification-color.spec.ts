import { DEFAULT_NOTIFICATION_COLOR, notificationColor } from '../lib/notification-color';

/** One colour per kind of push (owner 2026-11-18), same table as the app. */
describe('notificationColor', () => {
  it('colours by data.kind first', () => {
    expect(notificationColor('SYSTEM', { kind: 'reading_alert' })).toBe('#B3261E');
    expect(notificationColor('SYSTEM', { kind: 'caregiver_action' })).toBe('#0E7C86');
    expect(notificationColor('MISSED_DOSE_FAMILY_ALERT', { kind: 'test_pending' })).toBe('#B85A10');
  });

  it('then by type, then the default', () => {
    expect(notificationColor('MISSED_DOSE_FAMILY_ALERT', { memberUserId: 'u' })).toBe('#B85A10');
    expect(notificationColor('NOTICE', null)).toBe('#4A3D80');
    expect(notificationColor('SYSTEM', { kind: 'something_new' })).toBe(DEFAULT_NOTIFICATION_COLOR);
  });
});
