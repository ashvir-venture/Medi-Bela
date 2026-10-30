import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CatalogController } from '../catalog.controller';
import { PrescriptionsController } from '../../prescriptions/prescriptions.controller';
import { AdminDashboardController } from '../../admin/admin-dashboard.controller';
import { PharmacistDashboardController } from '../../admin/pharmacist-dashboard.controller';
import { PharmacistRoutinesController } from '../../health/pharmacist-routines.controller';
import { AuditLogController } from '../../audit/audit-log.controller';
import { AdminUsersController } from '../../admin/admin-users.controller';
import { HealthSuggestionsController } from '../../health/health-suggestions.controller';

type Ctor = { prototype: object };

/** Runs the real RolesGuard against a controller handler. */
function allowed(controller: Ctor, handler: string, role: Role): boolean {
  const context = {
    getHandler: () => (controller.prototype as Record<string, unknown>)[handler],
    getClass: () => controller,
    switchToHttp: () => ({ getRequest: () => ({ user: { id: 'u1', role } }) }),
  } as unknown as ExecutionContext;
  return new RolesGuard(new Reflector()).canActivate(context);
}

function roles(controller: Ctor, handler: string) {
  return [Role.ADMIN, Role.PHARMACIST, Role.USER].filter((r) => allowed(controller, handler, r));
}

describe('staff roles (Round 5 split)', () => {
  it('only pharmacists change doctors, medicines and tests; both staff roles read', () => {
    for (const h of ['createDoctor', 'updateDoctor', 'createMedicine', 'updateMedicine', 'createTest']) {
      expect(roles(CatalogController, h)).toEqual([Role.PHARMACIST]);
    }
    for (const h of ['searchDoctors', 'searchTests', 'searchGenerics', 'listDoctors', 'listMedicines']) {
      expect(roles(CatalogController, h)).toEqual([Role.ADMIN, Role.PHARMACIST]);
    }
    // Patients add their own medicines with the same suggestions (read-only).
    expect(roles(CatalogController, 'searchMedicines')).toEqual([Role.ADMIN, Role.PHARMACIST, Role.USER]);
  });

  it('only pharmacists prepare or reject prescriptions; admins can read them', () => {
    for (const h of ['saveDetails', 'saveMedicines', 'removeMedicine', 'complete', 'reject']) {
      expect(roles(PrescriptionsController, h)).toEqual([Role.PHARMACIST]);
    }
    for (const h of ['listQueue', 'getForAdmin']) {
      expect(roles(PrescriptionsController, h)).toEqual([Role.ADMIN, Role.PHARMACIST]);
    }
  });

  it('each staff role has its own dashboard', () => {
    expect(roles(AdminDashboardController, 'get')).toEqual([Role.ADMIN]);
    expect(roles(PharmacistDashboardController, 'get')).toEqual([Role.PHARMACIST]);
  });

  it('routines panel and AI suggestions are pharmacist only', () => {
    for (const h of ['list', 'detail', 'request']) {
      expect(roles(PharmacistRoutinesController, h)).toEqual([Role.PHARMACIST]);
    }
    for (const h of ['list', 'getDetail', 'update', 'publish', 'unpublish']) {
      expect(roles(HealthSuggestionsController, h)).toEqual([Role.PHARMACIST]);
    }
    // The user's own published suggestions stay open to every signed-in user.
    expect(roles(HealthSuggestionsController, 'getMine')).toEqual([Role.ADMIN, Role.PHARMACIST, Role.USER]);
  });

  it('the audit log is admin only', () => {
    for (const h of ['list', 'filters', 'detail']) {
      expect(roles(AuditLogController, h)).toEqual([Role.ADMIN]);
    }
  });

  it('the users page and ban / unban are admin only', () => {
    for (const h of ['list', 'ban', 'unban']) {
      expect(roles(AdminUsersController, h)).toEqual([Role.ADMIN]);
    }
  });
});
