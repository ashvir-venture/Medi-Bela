'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getAccessToken } from '@/lib/api-client';

/**
 * Minimal client-side guard: redirects to /login if no access token is
 * present. Real authorization (ADMIN/PHARMACIST role) is enforced by the
 * backend on every request regardless — this only prevents flashing
 * protected UI at a logged-out visitor.
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
