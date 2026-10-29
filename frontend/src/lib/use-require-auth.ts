'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AdminUser, ApiError, clearTokens, getAccessToken, getMe } from '@/lib/api-client';
import { StaffRole, homeFor, isStaffRole } from '@/lib/paths';

/**
 * Token present? Pages inside a role layout are only rendered after
 * [useRequireRole] has passed, so for them this is always ready; it stays
 * for pages that call it directly.
 */
export function useRequireAuth() {
  const router = useRouter();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace('/login');
      return;
    }
    setReady(true);
  }, [router]);

  return ready;
}

/**
 * Gate for a role's area (used by the area layouts). Loads the signed-in
 * user from the backend and:
 *  - no token / invalid token  -> /login
 *  - USER account               -> signed out, /login
 *  - the other staff role       -> that role's own dashboard
 * The backend enforces every role check again on each request; this only
 * keeps a role from seeing screens it can't use.
 */
export function useRequireRole(role: StaffRole) {
  const router = useRouter();
  const [user, setUser] = useState<AdminUser | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace('/login');
      return;
    }
    let cancelled = false;
    setError(null);
    getMe()
      .then((me) => {
        if (cancelled) return;
        if (me.role === role) {
          setUser(me);
        } else if (isStaffRole(me.role)) {
          router.replace(homeFor(me.role));
        } else {
          clearTokens();
          router.replace('/login');
        }
      })
      .catch((err) => {
        if (cancelled) return;
        // 401 already sent the browser to /login (api-client).
        if (!(err instanceof ApiError && err.status === 401)) {
          setError(err instanceof ApiError ? err.message : 'Could not reach the server');
        }
      });
    return () => {
      cancelled = true;
    };
  }, [role, router, attempt]);

  const retry = useCallback(() => setAttempt((n) => n + 1), []);
  return { user, error, retry };
}
