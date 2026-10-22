'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  ApiError,
  Notice,
  archiveNotice,
  deleteNotice,
  getNotice,
  publishNotice,
  updateNotice,
} from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

/** ISO string -> value for <input type="datetime-local"> in the browser's timezone. */
function toLocalInput(iso: string | null) {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export default function NoticeDetailPage() {
  const ready = useRequireAuth();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params.id;

  const [notice, setNotice] = useState<Notice | null>(null);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [audience, setAudience] = useState<'ALL' | 'USER' | 'ADMIN'>('ALL');
  const [expiresAt, setExpiresAt] = useState(''); // datetime-local value; empty = no expiry
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (!ready) return;
    load();
  }, [ready, id]);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const n = await getNotice(id);
      setNotice(n);
      setTitle(n.title);
      setContent(n.content);
      setAudience(n.audience);
      setExpiresAt(toLocalInput(n.expiresAt));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load notice');
    } finally {
      setIsLoading(false);
    }
  }

  function applyNotice(n: Notice) {
    setNotice(n);
    setExpiresAt(toLocalInput(n.expiresAt));
  }

  // Empty field => null => the backend removes the expiry.
  function payload() {
    return {
      title: title.trim(),
      content: content.trim(),
      audience,
      expiresAt: expiresAt ? new Date(expiresAt).toISOString() : null,
    };
  }

  async function handleSave() {
    setIsSaving(true);
    setError(null);
    try {
      applyNotice(await updateNotice(id, payload()));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to save');
    } finally {
      setIsSaving(false);
    }
  }

  async function handlePublish() {
    setIsSaving(true);
    setError(null);
    try {
      await updateNotice(id, payload());
      applyNotice(await publishNotice(id));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to publish');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleArchive() {
    setIsSaving(true);
    setError(null);
    try {
      applyNotice(await archiveNotice(id));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to archive');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete() {
    if (!confirm('Delete this notice? This cannot be undone.')) return;
    setIsSaving(true);
    setError(null);
    try {
      await deleteNotice(id);
      router.push('/notices');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to delete');
      setIsSaving(false);
    }
  }

  if (!ready) return null;
  if (isLoading || !notice) {
    return (
      <>
        <Topbar title="Notice" />
        <div className="page">
          {error && <div className="error-banner">{error}</div>}
          {isLoading && <p className="muted">Loading…</p>}
        </div>
      </>
    );
  }

  return (
    <>
      <Topbar title={notice.title} />
      <div className="page">
        <button className="btn" style={{ marginBottom: 16 }} onClick={() => router.push('/notices')}>
          ← Back
        </button>

        {error && <div className="error-banner">{error}</div>}

        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <span
              className={`badge ${notice.status === 'PUBLISHED' ? 'badge-completed' : notice.status === 'ARCHIVED' ? 'badge-rejected' : 'badge-draft'}`}
            >
              {notice.status}
            </span>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn" onClick={handleSave} disabled={isSaving}>
                Save
              </button>
              {notice.status !== 'PUBLISHED' && (
                <button className="btn btn-primary" onClick={handlePublish} disabled={isSaving}>
                  Publish
                </button>
              )}
              {notice.status !== 'ARCHIVED' && (
                <button className="btn" onClick={handleArchive} disabled={isSaving}>
                  Archive
                </button>
              )}
              <button className="btn" onClick={handleDelete} disabled={isSaving}>
                Delete
              </button>
            </div>
          </div>

          <div className="field">
            <label>Title</label>
            <input className="input" value={title} onChange={(e) => setTitle(e.target.value)} />
          </div>
          <div className="field">
            <label>Content</label>
            <textarea rows={6} value={content} onChange={(e) => setContent(e.target.value)} />
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
              <label>Expires (leave empty for no expiry)</label>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  type="datetime-local"
                  className="input"
                  value={expiresAt}
                  onChange={(e) => setExpiresAt(e.target.value)}
                />
                {expiresAt && (
                  <button type="button" className="btn" onClick={() => setExpiresAt('')}>
                    Clear
                  </button>
                )}
              </div>
            </div>
          </div>
          {notice.status === 'PUBLISHED' && notice.expiresAt && new Date(notice.expiresAt).getTime() <= Date.now() && (
            <p className="muted" style={{ color: 'var(--color-warning)' }}>
              This notice has expired, so users no longer see it. Change or clear the expiry and Save to bring it back.
            </p>
          )}
          {notice.status !== 'PUBLISHED' && (
            <p className="muted">Users cannot see this notice until it is published.</p>
          )}
        </div>
      </div>
    </>
  );
}
