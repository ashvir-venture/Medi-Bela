'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiError, createNotice, publishNotice, submitNotice } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { EMPTY_NOTICE, NoticeFields, formToInput } from '@/components/notices/notice-fields';
import { ButtonSpinner } from '@/components/skeleton';

/**
 * New notice. Both roles can keep it as a draft; a pharmacist can also send
 * it straight for approval, an admin can publish it straight away.
 */
export function NoticeNew({ basePath, role }: { basePath: string; role: 'ADMIN' | 'PHARMACIST' }) {
  const router = useRouter();
  const isAdmin = role === 'ADMIN';
  const [value, setValue] = useState(EMPTY_NOTICE);
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  async function save(next: 'draft' | 'advance') {
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
      if (next === 'advance') {
        try {
          await (isAdmin ? publishNotice(notice.id) : submitNotice(notice.id));
        } catch (err) {
          // The draft exists; open it so nothing typed is lost.
          router.push(`${basePath}/${notice.id}`);
          throw err;
        }
      }
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
          {isAdmin
            ? 'Save it as a draft to finish later, or publish it now.'
            : 'Save it as a draft to finish later, or submit it now. Nobody sees it until an admin approves it.'}
        </p>
        {error && <div className="error-banner">{error}</div>}
        <form
          onSubmit={(e) => {
            e.preventDefault();
            save('advance');
          }}
          className="card"
        >
          <NoticeFields value={value} onChange={setValue} disabled={isSaving} />
          <div className="button-row">
            <button
              type="button"
              className="btn"
              disabled={isSaving}
              onClick={(e) => {
                // Same required-field checks as the main button.
                if (e.currentTarget.form?.reportValidity()) save('draft');
              }}
            >
              Save draft
            </button>
            <button type="submit" className="btn btn-primary" disabled={isSaving}>
              {isSaving && <ButtonSpinner />}{isSaving ? 'Saving…' : isAdmin ? 'Publish' : 'Submit for approval'}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
