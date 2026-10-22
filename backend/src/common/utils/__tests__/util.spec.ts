import { normalizePhone } from '../phone.util';
import { appDayBounds, atAppTime, startOfAppDay } from '../time.util';
import { messages } from '../../../notifications/notification-messages';
import { effectiveStatus } from '../../../medicine-schedule/lib/dose-status.util';

describe('normalizePhone', () => {
  it.each([
    ['+8801712345678', '+8801712345678'],
    ['8801712345678', '+8801712345678'],
    ['01712345678', '+8801712345678'],
    [' +880 1712-345 678 ', '+8801712345678'],
    ['008801712345678', '+8801712345678'],
    ['(+880) 17.12345678', '+8801712345678'],
  ])('%s -> %s', (input, expected) => expect(normalizePhone(input)).toBe(expected));
  it('is idempotent', () => expect(normalizePhone(normalizePhone('01712345678'))).toBe('+8801712345678'));
});

describe('app timezone helpers (Asia/Dhaka, UTC+6)', () => {
  it('day bounds are Dhaka midnight regardless of server TZ', () => {
    const { start, end } = appDayBounds(new Date('2026-03-05T20:00:00Z')); // 02:00 on 6 Mar Dhaka
    expect(start.toISOString()).toBe('2026-03-05T18:00:00.000Z');
    expect(end.toISOString()).toBe('2026-03-06T18:00:00.000Z');
  });
  it('23:59 and 00:00 Dhaka fall on different days', () => {
    expect(startOfAppDay(new Date('2026-03-05T17:59:00Z')).toISOString()).toBe('2026-03-04T18:00:00.000Z');
    expect(startOfAppDay(new Date('2026-03-05T18:00:00Z')).toISOString()).toBe('2026-03-05T18:00:00.000Z');
  });
  it('atAppTime converts a Dhaka wall-clock time to the right instant', () => {
    expect(atAppTime(new Date('2026-03-05T18:00:00Z'), '08:30').toISOString()).toBe('2026-03-06T02:30:00.000Z');
  });
  it('honours APP_UTC_OFFSET_MINUTES', () => {
    process.env.APP_UTC_OFFSET_MINUTES = '0';
    expect(startOfAppDay(new Date('2026-03-05T20:00:00Z')).toISOString()).toBe('2026-03-05T00:00:00.000Z');
    delete process.env.APP_UTC_OFFSET_MINUTES;
  });
});

describe('notification copy privacy', () => {
  it('missed-dose text names the person but carries no medicine/dose wording, in both languages', () => {
    for (const lang of ['EN', 'BN'] as const) {
      const m = messages.missedDoseFamily(lang, 'Rahim');
      expect(m.body).toContain('Rahim');
      expect(JSON.stringify(m)).not.toMatch(/mg|ml|tablet|Metformin/i);
    }
  });
  it('very long names are clipped', () => {
    expect(messages.missedDoseFamily('EN', 'x'.repeat(500)).body.length).toBeLessThan(140);
  });
});

describe('effectiveStatus', () => {
  const now = new Date('2026-03-05T12:00:00Z');
  it('treats an overdue PENDING dose as MISSED without a DB write, leaves others alone', () => {
    expect(effectiveStatus('PENDING', new Date('2026-03-05T09:00:00Z'), now)).toBe('MISSED');
    expect(effectiveStatus('PENDING', new Date('2026-03-05T11:00:00Z'), now)).toBe('PENDING');
    expect(effectiveStatus('TAKEN', new Date('2026-03-05T09:00:00Z'), now)).toBe('TAKEN');
  });
});
