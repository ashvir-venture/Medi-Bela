import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const BY_NAME = { name: 'asc' as const };

/**
 * Dropdown data. Every option list comes from a lookup table the owner
 * edits in the database; nothing here is hard-coded.
 */
@Injectable()
export class LookupsService {
  constructor(private readonly prisma: PrismaService) {}

  async getAll() {
    const [
      genders,
      divisions,
      districts,
      doctorSpecialties,
      medicineForms,
      medicineCategories,
      mealTimings,
      testCategories,
      conditions,
      testKinds,
    ] = await Promise.all([
      this.prisma.gender.findMany({ orderBy: { id: 'asc' } }),
      this.prisma.division.findMany({ orderBy: BY_NAME }),
      this.prisma.district.findMany({ orderBy: BY_NAME }),
      this.prisma.doctorSpecialty.findMany({ orderBy: BY_NAME }),
      this.prisma.medicineForm.findMany({ orderBy: BY_NAME }),
      this.prisma.medicineCategory.findMany({ orderBy: BY_NAME }),
      // Meal timings keep their seeded order (before / with / after meal).
      this.prisma.mealTiming.findMany({ orderBy: { id: 'asc' } }),
      this.prisma.testCategory.findMany({ orderBy: BY_NAME }),
      // Round 15-16: EN/BN rows in the owner's order.
      this.prisma.condition.findMany({ orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] }),
      this.prisma.testKind.findMany({
        orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
        include: { fields: { orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } },
      }),
    ]);
    return {
      genders,
      divisions,
      districts,
      doctorSpecialties,
      medicineForms,
      medicineCategories,
      mealTimings,
      testCategories,
      conditions,
      testKinds,
    };
  }

  getUpazilas(districtId: number) {
    return this.prisma.upazila.findMany({ where: { districtId }, orderBy: BY_NAME });
  }
}
