'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import {
  ApiError,
  CatalogMedicine,
  Lookups,
  getLookups,
  getMedicine,
  searchGenerics,
  updateMedicine,
} from '@/lib/api-client';
import { Autosuggest } from '@/components/autosuggest';
import { Topbar } from '@/components/topbar';

export default function MedicineDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [medicine, setMedicine] = useState<CatalogMedicine | null>(null);
  const [lookups, setLookups] = useState<Lookups | null>(null);
  const [form, setForm] = useState({ brandName: '', genericName: '', formId: '', categoryId: '', manufacturer: '' });
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    Promise.all([getMedicine(id), getLookups()])
      .then(([m, l]) => {
        setLookups(l);
        apply(m);
      })
      .catch((err) => setError(err instanceof ApiError ? err.message : 'Failed to load medicine'));
  }, [id]);

  function apply(m: CatalogMedicine) {
    setMedicine(m);
    setForm({
      brandName: m.brandName,
      genericName: m.genericName ?? '',
      formId: m.formId?.toString() ?? '',
      categoryId: m.categoryId?.toString() ?? '',
      manufacturer: m.manufacturer ?? '',
    });
  }

  const set = (key: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm((f) => ({ ...f, [key]: e.target.value }));

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setIsSaving(true);
    setError(null);
    setNotice(null);
    try {
      apply(
        await updateMedicine(id, {
          brandName: form.brandName.trim(),
          // A picked or typed name; the backend reuses a generic that matches ignoring case.
          // Empty removes it.
          genericName: form.genericName.trim(),
          formId: form.formId ? Number(form.formId) : undefined,
          categoryId: form.categoryId ? Number(form.categoryId) : undefined,
          manufacturer: form.manufacturer.trim() || undefined,
        }),
      );
      setNotice('Saved.');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Failed to save');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <>
      <Topbar
        title={medicine ? medicine.brandName : 'Medicine'}
        actions={
          <Link href="/medicines" className="btn">
            ← Medicines
          </Link>
        }
      />
      <div className="page">
        {error && <div className="error-banner">{error}</div>}
        {notice && <div className="success-banner">{notice}</div>}
        {!medicine || !lookups ? (
          !error && <p className="muted">Loading…</p>
        ) : (
          <form className="card" onSubmit={handleSave}>
            <div className="form-grid">
              <div className="field">
                <label htmlFor="brand">Brand name</label>
                <input id="brand" className="input" value={form.brandName} onChange={set('brandName')} required />
              </div>
              <div className="field">
                <label htmlFor="generic">Generic name</label>
                <Autosuggest
                  id="generic"
                  value={form.genericName}
                  onChange={(text) => setForm((f) => ({ ...f, genericName: text }))}
                  search={searchGenerics}
                  getKey={(g) => String(g.id)}
                  renderItem={(g) => g.name}
                  onPick={(g) => setForm((f) => ({ ...f, genericName: g.name }))}
                  placeholder="e.g. Paracetamol"
                />
              </div>
              <div className="field">
                <label htmlFor="form">Form</label>
                <select id="form" value={form.formId} onChange={set('formId')}>
                  <option value="">Not specified</option>
                  {lookups.medicineForms.map((f) => (
                    <option key={f.id} value={f.id}>
                      {f.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label htmlFor="category">Category</label>
                <select id="category" value={form.categoryId} onChange={set('categoryId')}>
                  <option value="">Not specified</option>
                  {lookups.medicineCategories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field span-2">
                <label htmlFor="maker">Manufacturer</label>
                <input id="maker" className="input" value={form.manufacturer} onChange={set('manufacturer')} />
              </div>
            </div>
            <p className="muted">
              Strength is not stored here; it is entered on each prescription line. Used on{' '}
              {medicine._count?.lines ?? 0} prescription line(s).
            </p>
            <button type="submit" className="btn btn-primary" disabled={isSaving}>
              {isSaving ? 'Saving…' : 'Save'}
            </button>
          </form>
        )}
      </div>
    </>
  );
}
