import { Prisma } from '@prisma/client';

/**
 * What a pharmacist must fill in before a record counts as complete. One rule
 * for the lists' "Only incomplete" filter, the `incomplete` flag on each row
 * and both dashboards' counts.
 *
 * Doctor: name, specialty, phone and chamber (the free-text address). BMDC
 * number and district are optional.
 * Medicine: brand name, form, category and manufacturer (e.g. Seclo - Tablet -
 * Gastric - Square Pharma). Generic name is optional.
 */
export const DOCTOR_INCOMPLETE_WHERE: Prisma.DoctorWhereInput = {
  OR: [{ name: '' }, { specialtyId: null }, { phone: null }, { chamber: null }],
};

export const MEDICINE_INCOMPLETE_WHERE: Prisma.MedicineWhereInput = {
  OR: [{ brandName: '' }, { formId: null }, { categoryId: null }, { manufacturer: null }],
};

export function isDoctorIncomplete(d: {
  name: string;
  specialtyId: number | null;
  phone: string | null;
  chamber: string | null;
}): boolean {
  return !d.name || d.specialtyId === null || !d.phone || !d.chamber;
}

export function isMedicineIncomplete(m: {
  brandName: string;
  formId: number | null;
  categoryId: number | null;
  manufacturer: string | null;
}): boolean {
  return !m.brandName || m.formId === null || m.categoryId === null || !m.manufacturer;
}
