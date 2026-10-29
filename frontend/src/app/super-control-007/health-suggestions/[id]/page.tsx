'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  ApiError,
  HealthSuggestion,
  SuggestionItem,
  getHealthSuggestion,
  publishHealthSuggestion,
  unpublishHealthSuggestion,
  updateHealthSuggestion,
} from '@/lib/api-client';
import { useRequireAuth } from '@/lib/use-require-auth';
import { Topbar } from '@/components/topbar';

function ItemsEditor({
  label,
  items,
  onChange,
}: {
  label: string;
  items: SuggestionItem[];
  onChange: (items: SuggestionItem[]) => void;
}) {
  function updateItem(i: number, field: keyof SuggestionItem, value: string) {
    onChange(items.map((item, idx) => (idx === i ? { ...item, [field]: value } : item)));
  }
  function removeItem(i: number) {
    onChange(items.filter((_, idx) => idx !== i));
  }
  function addItem() {
    onChange([...items, { category: '', text: '' }]);
  }

  return (
    <div className="card">
      <h2>{label}</h2>
      {items.length === 0 && <p className="muted">No items.</p>}
      {items.map((item, i) => (
        <div key={i} className="row" style={{ marginBottom: 8, alignItems: 'flex-start' }}>
          <div className="field" style={{ flex: '0 0 160px' }}>
            <label>Category</label>
            <input
              className="input"
              value={item.category}
              onChange={(e) => updateItem(i, 'category', e.target.value)}
            />
          </div>
          <div className="field">
            <label>Text</label>
            <input className="input" value={item.text} onChange={(e) => updateItem(i, 'text', e.target.value)} />
          </div>
          <button
            type="button"
            className="btn"
            style={{ marginTop: 22 }}
            onClick={() => removeItem(i)}
          >
            Remove
          </button>
        </div>
      ))}
      <button type="button" className="btn" onClick={addItem}>
        + Add item
      </button>
    </div>
  );
}

export default function HealthSuggestionDetailPage() {
  const ready = useRequireAuth();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params.id;

  const [suggestion, setSuggestion] = useState<HealthSuggestion | null>(null);
  const [itemsEn, setItemsEn] = useState<SuggestionItem[]>([]);
  const [itemsBn, setItemsBn] = useState<SuggestionItem[]>([]);
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
      const s = await getHealthSuggestion(id);
      setSuggestion(s);
      setItemsEn(s.itemsEn);
      setItemsBn(s.itemsBn);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to load suggestion');
    } finally {
      setIsLoading(false);
    }
  }

  async function handleSave() {
    setIsSaving(true);
    setError(null);
    try {
      const updated = await updateHealthSuggestion(id, { itemsEn, itemsBn });
      setSuggestion(updated);
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
      // Save any edits, then publish.
      await updateHealthSuggestion(id, { itemsEn, itemsBn });
      setSuggestion(await publishHealthSuggestion(id));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to publish');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleUnpublish() {
    setIsSaving(true);
    setError(null);
    try {
      setSuggestion(await unpublishHealthSuggestion(id));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to unpublish');
    } finally {
      setIsSaving(false);
    }
  }

  if (!ready) return null;
  if (isLoading) {
    return (
      <>
        <Topbar title="AI Suggestion" />
        <div className="page">
          <p className="muted">Loading…</p>
        </div>
      </>
    );
  }
  if (!suggestion) {
    return (
      <>
        <Topbar title="AI Suggestion" />
        <div className="page">
          {error && <div className="error-banner">{error}</div>}
        </div>
      </>
    );
  }

  return (
    <>
      <Topbar title={`AI Suggestion — ${suggestion.user.name}`} />
      <div className="page">
        <button className="btn" style={{ marginBottom: 16 }} onClick={() => router.push('/super-control-007/health-suggestions')}>
          ← Back
        </button>

        {error && <div className="error-banner">{error}</div>}

        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div className="muted">Patient</div>
              <div style={{ fontWeight: 600 }}>
                {suggestion.user.name} ({suggestion.user.phone})
              </div>
              <div className="muted" style={{ marginTop: 8 }}>
                Generated from: {suggestion.sourceMedicines}
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <span className={`badge ${suggestion.status === 'PUBLISHED' ? 'badge-completed' : 'badge-draft'}`}>
                {suggestion.status === 'PUBLISHED' ? 'Published' : 'Draft'}
              </span>
              <div style={{ marginTop: 12, display: 'flex', gap: 8 }}>
                <button className="btn" onClick={handleSave} disabled={isSaving}>
                  Save edits
                </button>
                {suggestion.status === 'PUBLISHED' ? (
                  <button className="btn" onClick={handleUnpublish} disabled={isSaving}>
                    Unpublish
                  </button>
                ) : (
                  <button className="btn btn-primary" onClick={handlePublish} disabled={isSaving}>
                    Publish
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>

        <ItemsEditor label="English" items={itemsEn} onChange={setItemsEn} />
        <ItemsEditor label="বাংলা (Bengali)" items={itemsBn} onChange={setItemsBn} />
      </div>
    </>
  );
}
