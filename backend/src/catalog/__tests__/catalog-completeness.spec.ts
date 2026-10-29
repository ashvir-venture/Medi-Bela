import { isDoctorIncomplete, isMedicineIncomplete } from '../lib/catalog-completeness';

describe('catalog completeness', () => {
  const doctor = {
    name: 'Dr. A',
    specialtyId: 1,
    phone: '01711000000',
    chamber: 'Popular, Dhanmondi',
  };
  const medicine = {
    brandName: 'Seclo',
    formId: 1,
    categoryId: 2,
    manufacturer: 'Square Pharma',
  };

  it('a doctor with name, specialty, phone and address is complete without BMDC or district', () => {
    expect(isDoctorIncomplete(doctor)).toBe(false);
  });

  it.each(['specialtyId', 'phone', 'chamber'] as const)('a doctor missing %s is incomplete', (field) => {
    expect(isDoctorIncomplete({ ...doctor, [field]: null })).toBe(true);
  });

  it('a medicine with name, form, category and manufacturer is complete without a generic name', () => {
    expect(isMedicineIncomplete(medicine)).toBe(false);
  });

  it.each(['formId', 'categoryId', 'manufacturer'] as const)(
    'a medicine missing %s is incomplete',
    (field) => {
      expect(isMedicineIncomplete({ ...medicine, [field]: null })).toBe(true);
    },
  );
});
