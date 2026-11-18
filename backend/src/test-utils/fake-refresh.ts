/** A RefreshTokenService stand-in for AuthService unit specs (Round 18). */
export const fakeRefresh = () =>
  ({
    issue: jest.fn(async () => ({ token: 'refresh-token', familyId: 'family-1', expiresAt: new Date(Date.now() + 86_400_000) })),
    rotate: jest.fn(),
    revokeByToken: jest.fn(async () => undefined),
    revokeAllForUser: jest.fn(async () => undefined),
  }) as any;
