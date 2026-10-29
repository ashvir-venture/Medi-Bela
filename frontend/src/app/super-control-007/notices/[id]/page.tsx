'use client';

import { NoticeDetail } from '@/components/notices/notice-detail';
import { ADMIN_BASE } from '@/lib/paths';

export default function NoticeDetailPage() {
  return <NoticeDetail basePath={`${ADMIN_BASE}/notices`} canPublish={true} />;
}
