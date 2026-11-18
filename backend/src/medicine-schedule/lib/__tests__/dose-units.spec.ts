import { boxUnitsPerDose, remainingUnits, unitsPerDose } from '../dose-units';

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

describe('box units for a syrup counted in ml (Round 18)', () => {
  it('a spoon is 5 ml, a tablespoon 15 ml, ml stays ml', () => {
    expect(boxUnitsPerDose('2 tsp', 'ml')).toBe(10);
    expect(boxUnitsPerDose('২ চামচ', 'ml')).toBe(10);
    expect(boxUnitsPerDose('1 tbsp', 'ml')).toBe(15);
    expect(boxUnitsPerDose('20 ml', 'ml')).toBe(20);
  });

  it('other units count as before', () => {
    expect(boxUnitsPerDose('2 tsp', 'spoon')).toBe(2);
    expect(boxUnitsPerDose('1/2 tablet', 'tablet')).toBe(0.5);
    expect(boxUnitsPerDose(null, null)).toBe(1);
  });
});
