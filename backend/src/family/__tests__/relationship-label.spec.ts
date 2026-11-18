import { Language } from '@prisma/client';
import { memberLabel, relationshipFor } from '../lib/relationship-label';

/** Owner 2026-11-18: "Baba" for the one who chose it, the name for everyone else. */
describe('relationship label', () => {
  const father = { id: 1, code: 'father', nameEn: 'Father', nameBn: 'বাবা' };
  const member = { relationToUserId: 'caregiver', relationship: father };

  it('the chooser reads the relationship in their language', () => {
    expect(memberLabel(member, 'Rahim', 'caregiver', Language.BN)).toBe('বাবা');
    expect(memberLabel(member, 'Rahim', 'caregiver', Language.EN)).toBe('Father');
  });

  it('anyone else, or no relationship, reads the name', () => {
    expect(memberLabel(member, 'Rahim', 'sister', Language.BN)).toBe('Rahim');
    expect(memberLabel({ relationToUserId: null, relationship: null }, 'Rahim', 'caregiver', Language.EN)).toBe('Rahim');
    expect(relationshipFor(member, 'sister')).toBeNull();
  });
});
