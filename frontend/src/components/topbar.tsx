'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { clearTokens } from '@/lib/api-client';

export function Topbar({ title }: { title: string }) {
  const router = useRouter();

  return (
    <div className="topbar">
      <div style={{ display: 'flex', alignItems: 'center', gap: 20 }}>
        {/* Put your logo at public/logo.png. Hidden automatically if missing. */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/logoEn.png"
          alt="Medi-Bela"
          style={{ height: 32, width: 'auto' }}
          onError={(e) => {
            e.currentTarget.style.display = 'none';
          }}
        />
        <h1>{title}</h1>
        <nav style={{ display: 'flex', gap: 14 }}>
          <Link href="/dashboard">Dashboard</Link>
          <Link href="/prescriptions">Prescriptions</Link>
          <Link href="/routines">Routines</Link>
          <Link href="/health-rules">Health Rules</Link>
          <Link href="/health-suggestions">AI Suggestions</Link>
          <Link href="/notices">Notices</Link>
        </nav>
      </div>
      <button
        className="btn"
        onClick={() => {
          clearTokens();
          router.push('/login');
        }}
      >
        Log out
      </button>
    </div>
  );
}
