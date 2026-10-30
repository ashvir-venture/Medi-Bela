import { ServiceUnavailableException } from '@nestjs/common';
import { MaintenanceGuard } from '../maintenance.guard';

function context(path: string): any {
  return { switchToHttp: () => ({ getRequest: () => ({ path }) }) };
}

const guard = (value?: string) => new MaintenanceGuard({ get: () => value } as any);

describe('MaintenanceGuard (MAINTENANCE_MODE)', () => {
  it('off (unset or false): everything passes', () => {
    expect(guard(undefined).canActivate(context('/api/users/me'))).toBe(true);
    expect(guard('false').canActivate(context('/api/auth/login'))).toBe(true);
  });

  it('on: 503 with code MAINTENANCE on every route, login included', () => {
    for (const value of ['true', '1']) {
      for (const path of ['/api/users/me', '/api/auth/login', '/api/admin/users']) {
        try {
          guard(value).canActivate(context(path));
          fail('expected 503');
        } catch (err) {
          expect(err).toBeInstanceOf(ServiceUnavailableException);
          expect((err as any).errorCode).toBe('MAINTENANCE');
        }
      }
    }
  });

  it('on: /health still answers', () => {
    expect(guard('true').canActivate(context('/api/health'))).toBe(true);
  });
});
