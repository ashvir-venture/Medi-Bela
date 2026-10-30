'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  ApiError,
  CONDITION_TYPE_MEDICINE_NAME_CONTAINS,
  createSuggestionRule,
} from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';
import { ButtonSpinner } from '@/components/skeleton';

export default function NewHealthRulePage() {
  const ready = useRequireAuth();
  const router = useRouter();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [conditionType, setConditionType] = useState(CONDITION_TYPE_MEDICINE_NAME_CONTAINS);
  const [conditionValue, setConditionValue] = useState('');
  const [suggestedAction, setSuggestedAction] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  if (!ready) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsSaving(true);
    try {
      const rule = await createSuggestionRule({
        name: name.trim(),
        description: description.trim() || undefined,
        conditionType,
        conditionValue: conditionValue.trim(),
        suggestedAction: suggestedAction.trim(),
      });
      router.push(`/health-rules/${rule.id}`);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to create rule');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <>
      <Topbar title="New Health Suggestion Rule" />
      <div className="page">
        <p className="muted" style={{ marginBottom: 16 }}>
          This creates an <strong>inactive</strong> rule. It won&rsquo;t suggest anything to users until you
          open it and press Activate.
        </p>
        {error && <div className="error-banner">{error}</div>}
        <form onSubmit={handleSubmit} className="card">
          <div className="field">
            <label>Rule name</label>
            <input
              className="input"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Metformin → blood sugar check"
              required
            />
          </div>
          <div className="field">
            <label>Description (optional, for other admins)</label>
            <textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} />
          </div>

          <div className="field">
            <label>Condition type</label>
            <select value={conditionType} onChange={(e) => setConditionType(e.target.value)}>
              <option value={CONDITION_TYPE_MEDICINE_NAME_CONTAINS}>
                Medicine name contains (exact, instant)
              </option>
            </select>
            <p className="muted" style={{ marginTop: 4 }}>
              Custom rules are fully deterministic and admin-authored. For open-ended,
              AI-generated suggestions per user, see the Health Suggestions page instead.
            </p>
          </div>

          <div className="field">
            <label>Medicine name or category keywords, comma-separated (e.g. &quot;metformin, glipizide&quot;) — case-insensitive</label>
            <input
              className="input"
              value={conditionValue}
              onChange={(e) => setConditionValue(e.target.value)}
              required
            />
          </div>

          <div className="field">
            <label>Reminder text shown to the user</label>
            <input
              className="input"
              value={suggestedAction}
              onChange={(e) => setSuggestedAction(e.target.value)}
              placeholder="e.g. Blood sugar check"
              required
            />
          </div>

          <button type="submit" className="btn btn-primary" disabled={isSaving}>
            {isSaving && <ButtonSpinner />}{isSaving ? 'Creating…' : 'Create draft'}
          </button>
        </form>
      </div>
    </>
  );
}
