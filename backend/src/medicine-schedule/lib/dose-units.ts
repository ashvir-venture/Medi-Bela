/**
 * How many units one dose uses, for the medicine box: the first number in
 * the dose amount ("2 tablets" = 2, "1/2 tablet" or "½" = 0.5, "1.5 tsp" =
 * 1.5); 1 when there is none (owner, 2026-10-31). Bengali digits count too.
 * The app has the same rule (medicine_box_models.dart unitsPerDose).
 */
export function unitsPerDose(doseAmount: string | null | undefined): number {
  if (!doseAmount) return 1;
  const text = doseAmount
    .replace(/[০-৯]/g, (d) => String('০১২৩৪৫৬৭৮৯'.indexOf(d)))
    .replace(/½/g, '1/2')
    .replace(/¼/g, '1/4');
  const fraction = text.match(/(\d+)\s*\/\s*(\d+)/);
  if (fraction && Number(fraction[2]) > 0) return Number(fraction[1]) / Number(fraction[2]);
  const number = text.match(/\d+(\.\d+)?/);
  const value = number ? Number(number[0]) : NaN;
  return Number.isFinite(value) && value > 0 ? value : 1;
}

/**
 * Round 18 (client point 6): what one dose uses in the box's own unit. A
 * syrup counted in ml ("200 ml bottle") with a dose of "2 tsp" / "২ চামচ"
 * uses 10 ml (a teaspoon is 5 ml, a tablespoon 15 ml); "10 ml" uses 10.
 * Any other unit counts as unitsPerDose. The app has the same rule.
 */
export function boxUnitsPerDose(doseAmount: string | null | undefined, boxUnit: string | null | undefined): number {
  const n = unitsPerDose(doseAmount);
  if (boxUnit !== 'ml' || !doseAmount) return n;
  const t = doseAmount.toLowerCase();
  if (/tbsp|tablespoon|টেবিল/.test(t)) return n * 15;
  if (/tsp|teaspoon|spoon|চামচ/.test(t)) return n * 5;
  return n;
}

/** Units left: what was counted minus the doses taken since. Never below 0. */
export function remainingUnits(quantity: number, perDose: number, takenSinceCount: number): number {
  return Math.max(0, quantity - perDose * takenSinceCount);
}
