'use client';

import { NoticeDetail } from '@/components/notices/notice-detail';

export default function NoticeDetailPage() {
  return <NoticeDetail basePath={'/notices'} canPublish={false} />;
}
