'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, login, rememberMe, saveTokens } from '@/lib/api-client';
import { homeFor, isStaffRole } from '@/lib/paths';
import { ThemeToggle } from '@/components/theme-toggle';

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);

    try {
      const result = await login(phone, password);
      const role = result.user.role;
      if (!isStaffRole(role)) {
        setError('This account does not have admin/pharmacist access.');
        return;
      }
      saveTokens(result.tokens.accessToken);
      rememberMe(result.user);
      // Each role has its own area; the admin area is not linked from here.
      router.push(homeFor(role));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Login failed');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="auth">
      <aside className="auth-brand">
        <MedicineArt />
        <div className="auth-brand-content">
          {/* The logo carries the name and tagline, so no text title beside it. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logoEn.png" alt="Medi-Bela: Right time, healthy life" className="auth-logo" />
          <p className="auth-brand-lead">
            Verified prescriptions, timely medicine reminders and family care, managed in one place.
          </p>
          <ul className="auth-points">
            <li>Prescription review</li>
            <li>Medicine catalog</li>
            <li>Health notices</li>
          </ul>
        </div>
      </aside>

      <main className="auth-main">
        <div className="auth-theme">
          <ThemeToggle />
        </div>

        <div className="auth-card">
          <h1>Sign in</h1>
          <p className="muted auth-sub">Medi-Bela Management, for pharmacist and admin accounts.</p>
          {error && <div className="error-banner">{error}</div>}
          <form onSubmit={handleSubmit} autoComplete="off" className="auth-form">
            <div className="field">
              <label htmlFor="phone">Phone number</label>
              <input
                id="phone"
                className="input"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+8801XXXXXXXXX"
                inputMode="tel"
                required
              />
            </div>
            <div className="field">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                className="input"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>
            <button type="submit" className="btn btn-primary btn-block auth-submit" disabled={isSubmitting}>
              {isSubmitting ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
        </div>
      </main>
    </div>
  );
}

/** Light line art behind the brand panel: capsules, tablets, a cross and a pulse line. */
function MedicineArt() {
  return (
    <svg className="auth-art" viewBox="0 0 600 800" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
      <g fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        {/* capsule, top left */}
        <g transform="rotate(-35 110 120)">
          <rect x="60" y="100" width="100" height="40" rx="20" />
          <path d="M110 100v40" />
        </g>
        {/* round tablet, top right */}
        <circle cx="500" cy="110" r="26" />
        <path d="M482 110h36" />
        {/* cross, right */}
        <path d="M520 330h20v-20h20v20h20v20h-20v20h-20v-20h-20z" />
        {/* small tablets */}
        <circle cx="70" cy="420" r="12" />
        <circle cx="560" cy="560" r="10" />
        {/* capsule, bottom right */}
        <g transform="rotate(30 470 690)">
          <rect x="420" y="670" width="100" height="40" rx="20" />
          <path d="M470 670v40" />
        </g>
        {/* cross, bottom left */}
        <path d="M70 690h14v-14h14v14h14v14h-14v14H84v-14H70z" />
        {/* pulse line */}
        <path className="auth-art-pulse" d="M0 600h170l18-40 24 80 22-110 20 70h346" />
      </g>
    </svg>
  );
}
