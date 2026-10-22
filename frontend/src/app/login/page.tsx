'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, login, saveTokens } from '@/lib/api-client';

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

    console.log('LOGIN RESULT:', result);
    console.log('USER:', result.user);
    console.log('TOKENS:', result.tokens);

    if (result.user.role !== 'ADMIN' && result.user.role !== 'PHARMACIST') {
      setError('This account does not have admin/pharmacist access.');
      return;
    }

    saveTokens(result.tokens.accessToken);

    console.log(
      'SAVED TOKEN:',
      localStorage.getItem('carebridge_admin_access_token'),
    );

    router.push('/dashboard');
  } catch (err) {
    console.error('LOGIN ERROR:', err);
    setError(err instanceof ApiError ? err.message : 'Login failed');
  } finally {
    setIsSubmitting(false);
  }
}

  return (
    <div className="login-wrapper">
      <div className="card login-card">
        <h2>Medi-Bela Admin</h2>
        <p className="muted">Sign in with your admin or pharmacist account.</p>
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
          <button type="submit" className="btn btn-primary" disabled={isSubmitting} style={{ width: '100%' }}>
            {isSubmitting ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  );
}
