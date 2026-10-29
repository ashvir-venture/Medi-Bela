'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, createNotice } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';

export function NoticeNew({ basePath }: { basePath: string }) {
  const router = useRouter();

  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [audience, setAudience] = useState<'ALL' | 'USER' | 'ADMIN'>('ALL');
  const [expiresAt, setExpiresAt] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);


  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsSaving(true);
    try {
      const notice = await createNotice({
        title: title.trim(),
        content: content.trim(),
        audience,
        expiresAt: expiresAt ? new Date(expiresAt).toISOString() : undefined,
      });
      router.push(`${basePath}/${notice.id}`);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to create notice');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <>
      <Topbar title="New Notice" />
      <div className="page">
        <p className="muted" style={{ marginBottom: 16 }}>
          This creates a <strong>draft</strong>. Nobody sees it until an admin publishes it.
        </p>
        {error && <div className="error-banner">{error}</div>}
        <form onSubmit={handleSubmit} className="card">
          <div className="field">
            <label>Title</label>
            <input className="input" value={title} onChange={(e) => setTitle(e.target.value)} required />
          </div>
          <div className="field">
            <label>Content</label>
            <textarea rows={6} value={content} onChange={(e) => setContent(e.target.value)} required />
          </div>
          <div className="row">
            <div className="field">
              <label>Audience</label>
              <select value={audience} onChange={(e) => setAudience(e.target.value as typeof audience)}>
                <option value="ALL">Everyone</option>
                <option value="USER">Patients only</option>
                <option value="ADMIN">Admins/pharmacists only</option>
              </select>
            </div>
            <div className="field">
              <label>Expires (optional)</label>
              <input
                type="datetime-local"
                className="input"
                value={expiresAt}
                onChange={(e) => setExpiresAt(e.target.value)}
              />
            </div>
          </div>
          <button type="submit" className="btn btn-primary" disabled={isSaving}>
            {isSaving ? 'Creating…' : 'Create draft'}
          </button>
        </form>
      </div>
    </>
  );
}
