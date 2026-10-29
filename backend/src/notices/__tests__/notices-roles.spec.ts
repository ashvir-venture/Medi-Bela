import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { RolesGuard } from '../../common/guards/roles.guard';
import { NoticesController } from '../notices.controller';

/** Runs the real RolesGuard against a NoticesController handler. */
function allowed(handler: keyof NoticesController, role: Role): boolean {
  const context = {
    getHandler: () => NoticesController.prototype[handler],
    getClass: () => NoticesController,
    switchToHttp: () => ({ getRequest: () => ({ user: { id: 'u1', role } }) }),
  } as unknown as ExecutionContext;
  return new RolesGuard(new Reflector()).canActivate(context);
}

describe('notice roles', () => {
  it('only admins can publish', () => {
    expect(allowed('publish', Role.ADMIN)).toBe(true);
    expect(allowed('publish', Role.PHARMACIST)).toBe(false);
    expect(allowed('publish', Role.USER)).toBe(false);
  });

  it('pharmacists can still draft and edit (the service limits them to drafts)', () => {
    expect(allowed('create', Role.PHARMACIST)).toBe(true);
    expect(allowed('update', Role.PHARMACIST)).toBe(true);
  });

  it('pharmacists submit and withdraw; admins send back and archive', () => {
    for (const h of ['submit', 'withdraw'] as const) {
      expect(allowed(h, Role.PHARMACIST)).toBe(true);
      expect(allowed(h, Role.ADMIN)).toBe(false);
    }
    for (const h of ['sendBack', 'archive'] as const) {
      expect(allowed(h, Role.ADMIN)).toBe(true);
      expect(allowed(h, Role.PHARMACIST)).toBe(false);
    }
  });
});
