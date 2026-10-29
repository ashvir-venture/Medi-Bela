'use client';

import { NoticeList } from '@/components/notices/notice-list';
import { ADMIN_BASE } from '@/lib/paths';

export default function NoticesPage() {
  return <NoticeList basePath={`${ADMIN_BASE}/notices`} role="ADMIN" />;
}
