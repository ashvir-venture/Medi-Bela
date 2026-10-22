import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export const ROLES_KEY = 'roles';

/**
 * Restricts a route to the given roles. Must be combined with `JwtAuthGuard`
 * (which populates `request.user`) and `RolesGuard` (which reads this
 * metadata). Example: `@Roles(Role.ADMIN)`.
 */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
