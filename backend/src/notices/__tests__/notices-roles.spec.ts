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

  it('pharmacists can still draft and edit', () => {
    expect(allowed('create', Role.PHARMACIST)).toBe(true);
    expect(allowed('update', Role.PHARMACIST)).toBe(true);
  });
});
