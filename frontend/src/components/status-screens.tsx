'use client';

import { useEffect, useState } from 'react';
import { MAINTENANCE_EVENT } from '@/lib/api-client';

/** Top banner while the browser is offline (navigator.onLine + online/offline events). */
export function OfflineBanner() {
  const [offline, setOffline] = useState(false);

  useEffect(() => {
    const update = () => setOffline(!navigator.onLine);
    update();
    window.addEventListener('online', update);
    window.addEventListener('offline', update);
    return () => {
      window.removeEventListener('online', update);
      window.removeEventListener('offline', update);
    };
  }, []);

  if (!offline) return null;
  return (
    <div className="offline-banner" role="status">
      You&rsquo;re offline. Changes can&rsquo;t be saved until you&rsquo;re back online.
    </div>
  );
}

/**
 * Full screen while the API answers 503 (MAINTENANCE_MODE on the server).
 * Any request that gets one raises the event; Try again reloads the page.
 */
export function MaintenanceGate({ children }: { children: React.ReactNode }) {
  const [down, setDown] = useState(false);

  useEffect(() => {
    const on = () => setDown(true);
    window.addEventListener(MAINTENANCE_EVENT, on);
    return () => window.removeEventListener(MAINTENANCE_EVENT, on);
  }, []);

  if (!down) return <>{children}</>;
  return (
    <main className="status-screen">
      <div className="status-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo-mark.png" alt="" className="status-logo" />
        <h1>Medi-Bela is being updated.</h1>
        <p className="muted">Please try again in a few minutes.</p>
        <button className="btn btn-primary" onClick={() => window.location.reload()}>
          Try again
        </button>
      </div>
    </main>
  );
}
