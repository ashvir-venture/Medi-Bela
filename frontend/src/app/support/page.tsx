import type { Metadata } from 'next';
import { PublicPage } from '@/components/public-pages';

export const metadata: Metadata = { title: 'Support · Medi-Bela' };

/** Public; also linked from the sidebar of both staff areas. */
export default function SupportPage() {
  return <PublicPage page="support" />;
}
