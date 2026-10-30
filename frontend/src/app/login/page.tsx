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
    <div className="signin">
      <div className="signin-theme">
        <ThemeToggle />
      </div>

      {/* Wide screens only: what the product does, told by three small cards. */}
      <section className="signin-story">
        <SigninLogo />
        <h2 className="signin-headline">Every prescription checked. Every dose on time.</h2>
        <p className="signin-lead">
          Review prescriptions, keep the medicine catalog right, and reach patients with timely notices, all in one
          place.
        </p>
        <div className="signin-cards" aria-hidden="true">
          <div className="story-card story-card-1">
            <div className="story-card-title">Napa 500 mg · 1+0+1 · after meal</div>
            <div className="story-card-meta">
              <span className="story-dot story-dot-green" />
              Checked by pharmacist
            </div>
          </div>
          <div className="story-card story-card-2">
            <div className="story-card-title">8:00 AM · 2 medicines</div>
            <div className="story-card-meta">
              <span className="story-chip">Taken</span>
            </div>
          </div>
          <div className="story-card story-card-3">
            <div className="story-card-title">Missed dose</div>
            <div className="story-card-meta">
              <span className="story-dot story-dot-amber" />
              Family notified
            </div>
          </div>
        </div>
        <p className="signin-foot">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
            <path d="M12 21a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM12 9v4l2.5 2M5 3 2 6M19 3l3 3" />
          </svg>
          Alarm-style reminders for patients, and family who know when a dose is missed.
        </p>
      </section>

      <main className="signin-main">
        <div className="signin-phone-logo">
          <SigninLogo />
        </div>
        <div className="signin-card">
          <h1>Sign in</h1>
          <p className="muted signin-sub">Medi-Bela Management · for pharmacists and admins</p>
          {error && <div className="error-banner">{error}</div>}
          <form onSubmit={handleSubmit} autoComplete="off" className="signin-form">
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
            <button type="submit" className="btn btn-primary btn-block signin-submit" disabled={isSubmitting}>
              {isSubmitting ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
        </div>
      </main>
    </div>
  );
}

/** Logo mark + wordmark in token colors, so it reads in light and dark. */
function SigninLogo() {
  return (
    <span className="brand signin-logo">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/logo-mark.png" alt="" className="brand-mark" />
      <span className="brand-text">
        <span className="brand-name">
          Medi<span className="brand-accent">-Bela</span>
        </span>
        <span className="brand-caption">Right time, healthy life</span>
      </span>
    </span>
  );
}
