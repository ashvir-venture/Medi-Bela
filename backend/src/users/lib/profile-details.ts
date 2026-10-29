import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface ProfileDetails {
  dateOfBirth?: string;
  genderId?: number;
  divisionId?: number;
  districtId?: number;
  upazilaId?: number;
}

const MAX_AGE_YEARS = 120;

/**
 * Checks the registration/profile details against the lookup tables, with
 * friendly 400s (the database's composite foreign keys would otherwise
 * reject a mismatched address with a 500). The address is all-or-nothing:
 * division, district and upazila change together.
 */
export async function assertValidDetails(prisma: PrismaService, d: ProfileDetails) {
  if (d.dateOfBirth !== undefined) {
    const dob = new Date(`${d.dateOfBirth}T00:00:00.000Z`);
    const now = new Date();
    const oldest = new Date(Date.UTC(now.getUTCFullYear() - MAX_AGE_YEARS, now.getUTCMonth(), now.getUTCDate()));
    if (Number.isNaN(dob.getTime()) || dob > now || dob < oldest) {
      throw new BadRequestException('Enter a valid date of birth');
    }
  }
  if (d.genderId !== undefined) {
    const gender = await prisma.gender.findUnique({ where: { id: d.genderId }, select: { id: true } });
    if (!gender) throw new BadRequestException('Choose a gender from the list');
  }

  const address = [d.divisionId, d.districtId, d.upazilaId];
  const given = address.filter((v) => v !== undefined).length;
  if (given === 0) return;
  if (given !== 3) {
    throw new BadRequestException('Choose your division, district and upazila together');
  }
  const upazila = await prisma.upazila.findUnique({
    where: { id: d.upazilaId },
    select: { districtId: true, district: { select: { divisionId: true } } },
  });
  if (!upazila || upazila.districtId !== d.districtId || upazila.district.divisionId !== d.divisionId) {
    throw new BadRequestException('The upazila must be in the chosen district, and the district in the chosen division');
  }
}

/** YYYY-MM-DD -> Date for the @db.Date column. */
export function dateOfBirthColumn(value: string | undefined) {
  return value === undefined ? undefined : new Date(`${value}T00:00:00.000Z`);
}
