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
  sendBackNotice,
  submitNotice,
  updateNotice,
  withdrawNotice,
} from '@/lib/api-client';
import { Topbar } from '@/components/topbar';
import { NoticeFields, NoticeFormValue, EMPTY_NOTICE, formToInput, noticeToForm } from '@/components/notices/notice-fields';

export const NOTICE_STATUS: Record<Notice['status'], { label: string; badge: string }> = {
  DRAFT: { label: 'Draft', badge: 'badge-draft' },
  PENDING_APPROVAL: { label: 'Waiting for approval', badge: 'badge-pending' },
  PUBLISHED: { label: 'Published', badge: 'badge-completed' },
  ARCHIVED: { label: 'Archived', badge: 'badge-rejected' },
};

/** Published but its start time hasn't come yet. */
export function isScheduled(n: Notice) {
  return n.status === 'PUBLISHED' && n.publishedAt === null;
}

/**
 * One notice. Pharmacists edit their drafts, submit them for approval and
 * may withdraw a pending one; admins edit anything, approve/publish, send
 * back with a note, archive and delete. The backend enforces the same.
 */
export function NoticeDetail({ basePath, role }: { basePath: string; role: 'ADMIN' | 'PHARMACIST' }) {
  const router = useRouter();
  const { id } = useParams<{ id: string }>();
  const isAdmin = role === 'ADMIN';

  const [notice, setNotice] = useState<Notice | null>(null);
  const [value, setValue] = useState<NoticeFormValue>(EMPTY_NOTICE);
  const [note, setNote] = useState('');
  const [showSendBack, setShowSendBack] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  function apply(n: Notice) {
    setNotice(n);
    setValue(noticeToForm(n));
  }

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      apply(await getNotice(id));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load notice');
    } finally {
      setIsLoading(false);
    }
  }

  async function run(fallback: string, action: () => Promise<Notice | void>) {
    setIsSaving(true);
    setError(null);
    try {
      const result = await action();
      if (result) apply(result);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : fallback);
    } finally {
      setIsSaving(false);
    }
  }

  // Edits are saved before a status change, so the reviewer sees the latest text.
  const save = () => updateNotice(id, formToInput(value));
  const handleSave = () => run('Failed to save', save);
  const handleSubmit = () => run('Failed to submit', async () => (await save(), submitNotice(id)));
  const handleWithdraw = () => run('Failed to withdraw', () => withdrawNotice(id));
  const handlePublish = () => run('Failed to publish', async () => (await save(), publishNotice(id)));
  const handleArchive = () => run('Failed to archive', () => archiveNotice(id));
  const handleRestore = () => run('Failed to publish', () => publishNotice(id));
  function handleSendBack() {
    if (note.trim().length < 3) {
      setError('Write a short note for the pharmacist.');
      return;
    }
    return run('Failed to send back', async () => {
      const n = await sendBackNotice(id, note.trim());
      setShowSendBack(false);
      setNote('');
      return n;
    });
  }
  async function handleDelete() {
    if (!confirm('Delete this notice? This cannot be undone.')) return;
    await run('Failed to delete', async () => {
      await deleteNotice(id);
      router.push(basePath);
    });
  }

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

  const s = notice.status;
  const pharmacistCanEdit = s === 'DRAFT';
  const canEdit = isAdmin || pharmacistCanEdit;
  const status = isScheduled(notice)
    ? { label: `Scheduled for ${new Date(notice.startsAt!).toLocaleString()}`, badge: 'badge-pending' }
    : NOTICE_STATUS[s];
  const expired = s === 'PUBLISHED' && notice.expiresAt && new Date(notice.expiresAt).getTime() <= Date.now();

  return (
    <>
      <Topbar
        title={notice.title}
        actions={
          <button className="btn" onClick={() => router.push(basePath)}>
            ← Notices
          </button>
        }
      />
      <div className="page">
        {error && <div className="error-banner">{error}</div>}
        {notice.reviewNote && s === 'DRAFT' && (
          <div className="info-banner" style={{ margin: '0 0 16px' }}>
            Sent back by an admin: “{notice.reviewNote}”
          </div>
        )}

        <div className="card">
          <div className="card-head" style={{ justifyContent: 'space-between', marginBottom: 16 }}>
            <div>
              <span className={`badge ${status.badge}`}>{status.label}</span>
              <div className="muted" style={{ marginTop: 6 }}>
                {notice.createdBy ? `By ${notice.createdBy.name}` : ''}
                {notice.approvedBy ? ` · approved by ${notice.approvedBy.name}` : ''}
              </div>
            </div>
            <div className="button-row">
              {canEdit && (
                <button className="btn" onClick={handleSave} disabled={isSaving}>
                  Save
                </button>
              )}
              {!isAdmin && s === 'DRAFT' && (
                <button className="btn btn-primary" onClick={handleSubmit} disabled={isSaving}>
                  Submit for approval
                </button>
              )}
              {!isAdmin && s === 'PENDING_APPROVAL' && (
                <button className="btn" onClick={handleWithdraw} disabled={isSaving}>
                  Withdraw to draft
                </button>
              )}
              {isAdmin && (s === 'DRAFT' || s === 'PENDING_APPROVAL') && (
                <button className="btn btn-primary" onClick={handlePublish} disabled={isSaving}>
                  {s === 'PENDING_APPROVAL' ? 'Approve and publish' : 'Publish'}
                </button>
              )}
              {isAdmin && s === 'PENDING_APPROVAL' && (
                <button className="btn btn-danger" onClick={() => setShowSendBack((v) => !v)} disabled={isSaving}>
                  Send back
                </button>
              )}
              {isAdmin && s === 'PUBLISHED' && (
                <button className="btn" onClick={handleArchive} disabled={isSaving}>
                  Archive
                </button>
              )}
              {isAdmin && s === 'ARCHIVED' && (
                <button className="btn" onClick={handleRestore} disabled={isSaving}>
                  Publish again
                </button>
              )}
              {(isAdmin || s === 'DRAFT') && (
                <button className="btn" onClick={handleDelete} disabled={isSaving}>
                  Delete
                </button>
              )}
            </div>
          </div>

          {showSendBack && (
            <div className="field">
              <label htmlFor="send-back-note">Note for the pharmacist</label>
              <textarea
                id="send-back-note"
                rows={2}
                value={note}
                onChange={(e) => setNote(e.target.value)}
                maxLength={500}
                placeholder="What should change before it can be published?"
              />
              <button className="btn btn-danger" style={{ marginTop: 8 }} onClick={handleSendBack} disabled={isSaving}>
                Send back to draft
              </button>
            </div>
          )}

          <NoticeFields value={value} onChange={setValue} disabled={isSaving || !canEdit} />

          {expired && (
            <p className="muted" style={{ color: 'var(--color-warning)' }}>
              This notice has expired, so users no longer see it. Change or clear the expiry and Save to bring it back.
            </p>
          )}
          {!canEdit && (
            <p className="muted">
              {s === 'PENDING_APPROVAL' ? 'Withdraw it to draft to make changes.' : 'Only an admin can change it now.'}
            </p>
          )}
          {s !== 'PUBLISHED' && (
            <p className="muted">Users cannot see this notice until an admin publishes it.</p>
          )}
        </div>
      </div>
    </>
  );
}
