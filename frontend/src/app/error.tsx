'use client';

import { ApiError } from '@/lib/api-client';

/** A page crashed while rendering: say so, offer Try again, show the support ref when known. */
export default function ErrorPage({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const ref = error instanceof ApiError ? error.ref : undefined;
  return (
    <main className="status-screen">
      <div className="status-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo-mark.png" alt="" className="status-logo" />
        <h1>Something went wrong</h1>
        <p className="muted">{ref ? `Ref: ${ref}` : 'Try again. If it keeps happening, tell the Medi-Bela team.'}</p>
        <button className="btn btn-primary" onClick={reset}>
          Try again
        </button>
      </div>
    </main>
  );
}
