import type { Metadata } from 'next';
import { PublicPage } from '@/components/public-pages';

export const metadata: Metadata = { title: 'Privacy & terms · Medi-Bela' };

/** Public (the Play Store privacy URL); no sign-in. */
export default function PrivacyPage() {
  return <PublicPage page="privacy" />;
}
