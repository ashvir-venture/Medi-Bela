import { Role } from '@prisma/client';

/** Claims encoded inside the access JWT. */
export interface JwtPayload {
  /** Subject — the user's id (uuid). */
  sub: string;
  phone: string;
  role: Role;
}

/** The shape `request.user` takes once a JWT has been validated. */
export interface AuthenticatedUser {
  id: string;
  phone: string;
  role: Role;
}
