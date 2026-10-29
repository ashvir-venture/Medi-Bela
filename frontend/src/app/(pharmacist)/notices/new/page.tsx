'use client';

import { NoticeNew } from '@/components/notices/notice-new';

export default function NewNoticePage() {
  return <NoticeNew basePath={'/notices'} role="PHARMACIST" />;
}
