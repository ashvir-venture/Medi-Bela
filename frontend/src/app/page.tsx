'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { clearTokens, getAccessToken, getMe } from '@/lib/api-client';
import { homeFor, isStaffRole } from '@/lib/paths';
import { Skeleton } from '@/components/skeleton';

/** Sends a signed-in staff member to their own dashboard, everyone else to login. */
export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace('/login');
      return;
    }
    getMe()
      .then((me) => {
        if (isStaffRole(me.role)) {
          router.replace(homeFor(me.role));
        } else {
          clearTokens();
          router.replace('/login');
        }
      })
      .catch(() => router.replace('/login'));
  }, [router]);

  return (
    <div className="login-wrapper">
      <Skeleton kind="page" />
    </div>
  );
}
