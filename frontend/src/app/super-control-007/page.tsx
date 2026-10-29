'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ADMIN_BASE } from '@/lib/paths';

export default function AdminIndexPage() {
  const router = useRouter();
  useEffect(() => router.replace(`${ADMIN_BASE}/dashboard`), [router]);
  return null;
}
