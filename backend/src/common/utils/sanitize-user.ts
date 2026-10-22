import { User } from '@prisma/client';

export type SafeUser = Omit<User, 'passwordHash'>;

/** Strips fields that must never be serialized back to a client. */
export function sanitizeUser(user: User): SafeUser {
  const { passwordHash, ...safeUser } = user;
  return safeUser;
}
