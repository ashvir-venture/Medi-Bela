import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Marks a route as not requiring authentication. Used by `JwtAuthGuard`,
 * which is applied globally so that every endpoint is protected by default.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
