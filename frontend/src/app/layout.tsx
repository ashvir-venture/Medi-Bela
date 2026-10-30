import type { Metadata } from 'next';
import { Hind_Siliguri, IBM_Plex_Sans } from 'next/font/google';
import { THEME_BOOT_SCRIPT } from '@/lib/theme';
import { MaintenanceGate, OfflineBanner } from '@/components/status-screens';
import { ToastProvider } from '@/components/toast';
import { ConfirmProvider } from '@/components/confirm-dialog';
import './globals.css';

// Downloaded at build time and served with the panel: no request to Google at runtime.
const plexSans = IBM_Plex_Sans({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-sans',
  display: 'swap',
});
const hindSiliguri = Hind_Siliguri({
  subsets: ['bengali', 'latin'],
  weight: ['400', '500', '600'],
  variable: '--font-bengali',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Medi-Bela Management',
  description: 'Medi-Bela management panel for pharmacists and admins',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    // The boot script may set data-theme before React hydrates.
    <html lang="en" className={`${plexSans.variable} ${hindSiliguri.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_BOOT_SCRIPT }} />
      </head>
      <body>
        <ToastProvider>
          <ConfirmProvider>
            <OfflineBanner />
            <MaintenanceGate>{children}</MaintenanceGate>
          </ConfirmProvider>
        </ToastProvider>
      </body>
    </html>
  );
}
