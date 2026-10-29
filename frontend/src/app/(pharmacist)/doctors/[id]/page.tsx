'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ApiError, Doctor, Lookups, getDoctor, getLookups, updateDoctor } from '@/lib/api-client';
import { Topbar } from '@/components/topbar';

export default function DoctorDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [doctor, setDoctor] = useState<Doctor | null>(null);
  const [lookups, setLookups] = useState<Lookups | null>(null);
  const [form, setForm] = useState({ name: '', bmdcNumber: '', specialtyId: '', chamber: '', phone: '', districtId: '' });
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    Promise.all([getDoctor(id), getLookups()])
      .then(([d, l]) => {
        setLookups(l);
        apply(d);
      })
      .catch((err) => setError(err instanceof ApiError ? err.message : 'Failed to load doctor'));
  }, [id]);

  function apply(d: Doctor) {
    setDoctor(d);
    setForm({
      name: d.name,
      bmdcNumber: d.bmdcNumber ?? '',
      specialtyId: d.specialtyId?.toString() ?? '',
      chamber: d.chamber ?? '',
      phone: d.phone ?? '',
      districtId: d.districtId?.toString() ?? '',
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
      // Only send what is filled: clearing a set field isn't needed for completing records.
      apply(
        await updateDoctor(id, {
          name: form.name.trim(),
          bmdcNumber: form.bmdcNumber.trim() || undefined,
          specialtyId: form.specialtyId ? Number(form.specialtyId) : undefined,
          chamber: form.chamber.trim() || undefined,
          phone: form.phone.trim() || undefined,
          districtId: form.districtId ? Number(form.districtId) : undefined,
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
        title={doctor ? doctor.name : 'Doctor'}
        actions={
          <Link href="/doctors" className="btn">
            ← Doctors
          </Link>
        }
      />
      <div className="page">
        {error && <div className="error-banner">{error}</div>}
        {notice && <div className="success-banner">{notice}</div>}
        {!doctor || !lookups ? (
          !error && <p className="muted">Loading…</p>
        ) : (
          <form className="card" onSubmit={handleSave}>
            <div className="form-grid">
              <div className="field span-2">
                <label htmlFor="name">Name</label>
                <input id="name" className="input" value={form.name} onChange={set('name')} required minLength={2} />
              </div>
              <div className="field">
                <label htmlFor="bmdc">BMDC number</label>
                <input id="bmdc" className="input" value={form.bmdcNumber} onChange={set('bmdcNumber')} placeholder="e.g. A-12345" />
              </div>
              <div className="field">
                <label htmlFor="specialty">Specialty</label>
                <select id="specialty" value={form.specialtyId} onChange={set('specialtyId')}>
                  <option value="">Not specified</option>
                  {lookups.doctorSpecialties.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label htmlFor="chamber">Chamber / hospital</label>
                <input id="chamber" className="input" value={form.chamber} onChange={set('chamber')} />
              </div>
              <div className="field">
                <label htmlFor="district">District</label>
                <select id="district" value={form.districtId} onChange={set('districtId')}>
                  <option value="">Not specified</option>
                  {lookups.districts.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label htmlFor="phone">Chamber phone</label>
                <input id="phone" className="input" inputMode="tel" value={form.phone} onChange={set('phone')} />
              </div>
            </div>
            <p className="muted">Used on {doctor._count?.prescriptions ?? 0} prescription(s).</p>
            <button type="submit" className="btn btn-primary" disabled={isSaving}>
              {isSaving ? 'Saving…' : 'Save'}
            </button>
          </form>
        )}
      </div>
    </>
  );
}
