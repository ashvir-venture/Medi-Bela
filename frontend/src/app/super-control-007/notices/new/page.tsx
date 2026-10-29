'use client';

import { NoticeNew } from '@/components/notices/notice-new';
import { ADMIN_BASE } from '@/lib/paths';

export default function NewNoticePage() {
  return <NoticeNew basePath={`${ADMIN_BASE}/notices`} />;
}
