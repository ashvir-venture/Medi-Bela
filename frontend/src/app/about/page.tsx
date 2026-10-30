import type { Metadata } from 'next';
import { PublicPage } from '@/components/public-pages';

export const metadata: Metadata = { title: 'About us · Medi-Bela' };

/** Public; no sign-in. */
export default function AboutPage() {
  return <PublicPage page="about" />;
}
