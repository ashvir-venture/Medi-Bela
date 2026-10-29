'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, createNotice } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { EMPTY_NOTICE, NoticeFields, formToInput } from '@/components/notices/notice-fields';

export function NoticeNew({ basePath, role }: { basePath: string; role: 'ADMIN' | 'PHARMACIST' }) {
  const router = useRouter();
  const [value, setValue] = useState(EMPTY_NOTICE);
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsSaving(true);
    try {
      const input = formToInput(value);
      // Nothing to clear on a new notice.
      const notice = await createNotice({
        ...input,
        source: input.source ?? undefined,
        sourceUrl: input.sourceUrl ?? undefined,
        startsAt: input.startsAt ?? undefined,
        expiresAt: input.expiresAt ?? undefined,
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
      <Topbar title="New notice" />
      <div className="page">
        <p className="muted" style={{ marginTop: 0 }}>
          {role === 'ADMIN'
            ? 'This creates a draft. Publish it from the next page.'
            : 'This creates a draft. Submit it for approval when it is ready; nobody sees it until an admin approves it.'}
        </p>
        {error && <div className="error-banner">{error}</div>}
        <form onSubmit={handleSubmit} className="card">
          <NoticeFields value={value} onChange={setValue} disabled={isSaving} />
          <button type="submit" className="btn btn-primary" disabled={isSaving}>
            {isSaving ? 'Creating…' : 'Create draft'}
          </button>
        </form>
      </div>
    </>
  );
}
