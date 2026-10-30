'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { getAccessToken } from '@/lib/api-client';

/** Unknown address: back to the dashboard, or to sign-in when signed out. */
export default function NotFound() {
  const [signedIn, setSignedIn] = useState(false);
  useEffect(() => setSignedIn(Boolean(getAccessToken())), []);

  return (
    <main className="status-screen">
      <div className="status-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo-mark.png" alt="" className="status-logo" />
        <h1>Page not found</h1>
        <p className="muted">This address doesn&rsquo;t lead anywhere in Medi-Bela Management.</p>
        {/* "/" sends a signed-in staff member to their own dashboard. */}
        <Link href={signedIn ? '/' : '/login'} className="btn btn-primary">
          {signedIn ? 'Go to dashboard' : 'Sign in'}
        </Link>
      </div>
    </main>
  );
}
