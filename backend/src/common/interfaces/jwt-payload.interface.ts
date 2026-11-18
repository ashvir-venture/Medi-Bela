import { Role } from '@prisma/client';

/** Claims encoded inside the access JWT. */
export interface JwtPayload {
  /** Subject — the user's id (uuid). */
  sub: string;
  phone: string;
  role: Role;
  /** Round 18: the refresh-token family (this sign-in); a password change keeps it. */
  sid?: string;
}

/** The shape `request.user` takes once a JWT has been validated. */
export interface AuthenticatedUser {
  id: string;
  phone: string;
  role: Role;
  /** The sign-in (refresh-token family) this access token belongs to. */
  sid?: string;
}
