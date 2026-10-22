'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  ApiError,
  CONDITION_TYPE_MEDICINE_NAME_CONTAINS,
  SuggestionRule,
  getSuggestionRule,
  publishSuggestionRule,
  unpublishSuggestionRule,
  updateSuggestionRule,
} from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

export default function HealthRuleDetailPage() {
  const ready = useRequireAuth();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params.id;

  const [rule, setRule] = useState<SuggestionRule | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [conditionType, setConditionType] = useState(CONDITION_TYPE_MEDICINE_NAME_CONTAINS);
  const [conditionValue, setConditionValue] = useState('');
  const [suggestedAction, setSuggestedAction] = useState('');

  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (!ready) return;
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, id]);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const data = await getSuggestionRule(id);
      applyToForm(data);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load rule');
    } finally {
      setIsLoading(false);
    }
  }

  function applyToForm(data: SuggestionRule) {
    setRule(data);
    setName(data.name);
    setDescription(data.description ?? '');
    setConditionType(data.conditionType);
    setConditionValue(data.conditionValue);
    setSuggestedAction(data.suggestedAction);
  }

  async function handleSave() {
    setIsSaving(true);
    setError(null);
    setNotice(null);
    try {
      const updated = await updateSuggestionRule(id, {
        name: name.trim(),
        description: description.trim() || undefined,
        conditionType,
        conditionValue: conditionValue.trim(),
        suggestedAction: suggestedAction.trim(),
      });
      applyToForm(updated);
      setNotice('Saved.');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to save changes');
    } finally {
      setIsSaving(false);
    }
  }

  async function handlePublish() {
    setIsSaving(true);
    setError(null);
    setNotice(null);
    try {
      const { rule: updated, remindersCreated } = await publishSuggestionRule(id);
      applyToForm(updated);
      setNotice(
        remindersCreated > 0
          ? `Activated — ${remindersCreated} reminder(s) created for existing users right now.`
          : 'Activated — no existing verified medicines matched yet; it will apply to new prescriptions going forward.',
      );
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to publish rule');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleUnpublish() {
    setIsSaving(true);
    setError(null);
    setNotice(null);
    try {
      const updated = await unpublishSuggestionRule(id);
      applyToForm(updated);
      setNotice('Disabled. Reminders it already created are unaffected.');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to unpublish rule');
    } finally {
      setIsSaving(false);
    }
  }

  if (!ready) return null;

  return (
    <>
      <Topbar title="Edit Health Suggestion Rule" />
      <div className="page">
        <button className="btn" style={{ marginBottom: 16 }} onClick={() => router.push('/health-rules')}>
          ← Back to rules
        </button>

        {error && <div className="error-banner">{error}</div>}
        {notice && (
          <div className="card" style={{ background: '#f0fdf4', borderColor: '#bbf7d0' }}>
            {notice}
          </div>
        )}

        {isLoading || !rule ? (
          <p className="muted">Loading…</p>
        ) : (
          <>
            <div className="card">
              <h2>
                Status:{' '}
                <span className={`badge ${rule.enabled ? 'badge-completed' : 'badge-draft'}`}>
                  {rule.enabled ? 'Active' : 'Inactive'}
                </span>
              </h2>
              <p className="muted">
                {rule.enabled
                  ? 'This rule is active: it runs automatically on every new completed prescription.'
                  : 'This rule is inactive: it does nothing until you activate it.'}
              </p>
              <div style={{ display: 'flex', gap: 12 }}>
                {rule.enabled ? (
                  <button className="btn btn-danger" onClick={handleUnpublish} disabled={isSaving}>
                    Disable
                  </button>
                ) : (
                  <button className="btn btn-primary" onClick={handlePublish} disabled={isSaving}>
                    Activate
                  </button>
                )}
              </div>
            </div>

            <div className="card">
              <h2>Rule definition</h2>
              <p className="muted">
                IF medicine name contains any of &ldquo;{conditionValue || '…'}&rdquo; → health reminder: &ldquo;{suggestedAction || '…'}&rdquo;
              </p>

              <div className="field">
                <label>Rule name</label>
                <input className="input" value={name} onChange={(e) => setName(e.target.value)} />
              </div>
              <div className="field">
                <label>Description</label>
                <textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} />
              </div>
              <div className="field">
                <label>Condition type</label>
                <select value={conditionType} onChange={(e) => setConditionType(e.target.value)}>
                  <option value={CONDITION_TYPE_MEDICINE_NAME_CONTAINS}>
                    Medicine name contains (exact, instant)
                  </option>
                </select>
              </div>
              <div className="field">
                <label>Medicine name or category keywords (case-insensitive, comma-separated)</label>
                <input
                  className="input"
                  value={conditionValue}
                  onChange={(e) => setConditionValue(e.target.value)}
                />
              </div>
              <div className="field">
                <label>Reminder text shown to the user</label>
                <input
                  className="input"
                  value={suggestedAction}
                  onChange={(e) => setSuggestedAction(e.target.value)}
                />
              </div>

              <button className="btn btn-primary" onClick={handleSave} disabled={isSaving}>
                Save changes
              </button>
              <p className="muted" style={{ marginTop: 8 }}>
                Editing does not re-run the rule or change whether it is active — use Activate
                above for that. A category is just a list of names, e.g. &ldquo;metformin, glipizide&rdquo;.
                Reminders are plain text you write; no AI creates or changes rules.
              </p>
            </div>
          </>
        )}
      </div>
    </>
  );
}
