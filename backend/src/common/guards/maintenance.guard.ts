import { CanActivate, ExecutionContext, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { ErrorCode, withCode } from '../filters/error-codes';

export const MAINTENANCE_MESSAGE = 'Medi-Bela is being updated. Please try again in a few minutes.';

export function maintenanceOn(value: string | undefined): boolean {
  return value === 'true' || value === '1';
}

/**
 * MAINTENANCE_MODE=true: every route answers 503 (code MAINTENANCE) except
 * /health, so the apps show their "being updated" screen and a load balancer
 * still sees the process alive. The first global guard, so it answers before
 * sign-in is checked. Read on each request: changing the variable needs a
 * restart anyway, but tests can flip it.
 */
@Injectable()
export class MaintenanceGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    if (!maintenanceOn(this.config.get<string>('MAINTENANCE_MODE'))) return true;
    const request = context.switchToHttp().getRequest<Request>();
    if (request.path === '/api/health' || request.path === '/health') return true;
    throw withCode(new ServiceUnavailableException(MAINTENANCE_MESSAGE), ErrorCode.MAINTENANCE);
  }
}
