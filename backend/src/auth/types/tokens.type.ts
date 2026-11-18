export interface TokenPair {
  /** Short-lived (JWT_ACCESS_EXPIRES_IN, 15 min by default since Round 18). */
  accessToken: string;
  /** Round 18: the app's refresh token (the panel's goes in an httpOnly cookie instead). */
  refreshToken?: string;
  refreshExpiresAt?: string;
}
