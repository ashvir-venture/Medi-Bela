import { remainingUnits, unitsPerDose } from '../dose-units';

// Owner, 2026-10-31: a taken dose uses the number in its dose amount, else 1.
describe('unitsPerDose', () => {
  it.each([
    ['1 tablet', 1],
    ['2 tablets', 2],
    ['1/2 tablet', 0.5],
    ['½ tablet', 0.5],
    ['1.5 tsp', 1.5],
    ['২টি ট্যাবলেট', 2],
    ['one tablet', 1],
    ['', 1],
    [null, 1],
  ])('%s -> %s', (amount, units) => expect(unitsPerDose(amount as string | null)).toBe(units));
});

describe('remainingUnits', () => {
  it('counted minus the doses taken since, never below 0', () => {
    expect(remainingUnits(10, 2, 3)).toBe(4);
    expect(remainingUnits(3, 2, 2)).toBe(0);
  });
});
