import { takenWindow } from '../taken-window';

// Owner, 2026-10-31: a dose can be marked taken from its time until 1 hour
// before the same medicine's next dose. Times are Dhaka (UTC+6).
describe('takenWindow', () => {
  const eight = new Date('2026-01-10T02:00:00.000Z'); // 08:00, 10 Jan
  const routine = { scheduleTimes: '["08:00","14:00"]', intervalDays: 1 };

  it('08:00 with a 14:00 dose after it: open from 08:00 until 13:00', () => {
    const w = takenWindow({ scheduledAt: eight }, routine, new Date('2026-01-10T08:00:00.000Z'));
    expect(w.opensAt.toISOString()).toBe('2026-01-10T02:00:00.000Z');
    expect(w.closesAt.toISOString()).toBe('2026-01-10T07:00:00.000Z'); // 13:00
  });

  it('works the next dose out from the schedule when none is stored', () => {
    expect(takenWindow({ scheduledAt: eight }, routine, null).closesAt.toISOString()).toBe('2026-01-10T07:00:00.000Z');
    // The day's last time: next is 08:00 tomorrow -> closes 07:00 tomorrow.
    const two = new Date('2026-01-10T08:00:00.000Z');
    expect(takenWindow({ scheduledAt: two }, routine, null).closesAt.toISOString()).toBe('2026-01-11T01:00:00.000Z');
  });

  it('every 7 days: open until 1 hour before the dose a week later', () => {
    const weekly = { scheduleTimes: '["08:00"]', intervalDays: 7 };
    expect(takenWindow({ scheduledAt: eight }, weekly, null).closesAt.toISOString()).toBe('2026-01-17T01:00:00.000Z');
  });
});
