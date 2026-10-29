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
    <div className="login-wrapper">
      <div className="card login-card">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/logoEn.png"
          alt=""
          className="login-logo"
          onError={(e) => {
            e.currentTarget.style.display = 'none';
          }}
        />
        <h2>Medi-Bela</h2>
        <p className="muted">Sign in with your pharmacist or admin account.</p>
        {error && <div className="error-banner">{error}</div>}
        <form onSubmit={handleSubmit} autoComplete="off">
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
          <button type="submit" className="btn btn-primary btn-block" disabled={isSubmitting}>
            {isSubmitting ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
        <div style={{ marginTop: 16 }}>
          <ThemeToggle />
        </div>
      </div>
    </div>
  );
}
