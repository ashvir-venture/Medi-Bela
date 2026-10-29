import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Medi-Bela Staff',
  description: 'Pharmacist and admin panel',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
