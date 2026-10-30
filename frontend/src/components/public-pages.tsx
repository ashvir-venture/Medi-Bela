'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { PUBLIC_CONTENT, PublicContent, PublicLang, SUPPORT_CONTACTS } from '@/lib/public-content';
import { ThemeToggle } from '@/components/theme-toggle';
import { Icon } from '@/components/icons';
import { useToast } from '@/components/toast';

export type PublicPageName = 'privacy' | 'support' | 'about';

const LANG_KEY = 'medibela_public_lang';

/** The reader's language choice on the public pages, remembered in this browser when possible. */
function usePublicLang(): [PublicLang, (l: PublicLang) => void] {
  const [lang, setLang] = useState<PublicLang>('en');
  useEffect(() => {
    try {
      if (localStorage.getItem(LANG_KEY) === 'bn') setLang('bn');
    } catch {
      // storage blocked: English
    }
  }, []);
  const choose = (l: PublicLang) => {
    setLang(l);
    try {
      localStorage.setItem(LANG_KEY, l);
    } catch {
      // not remembered; fine
    }
  };
  return [lang, choose];
}

const NAV: { page: PublicPageName; href: string; title: (c: PublicContent) => string }[] = [
  { page: 'privacy', href: '/privacy', title: (c) => c.privacyTitle },
  { page: 'support', href: '/support', title: (c) => c.supportTitle },
  { page: 'about', href: '/about', title: (c) => c.aboutTitle },
];

/**
 * Privacy & terms, Support and About us: public (no sign-in, outside the
 * role layouts), with one header and footer and an English | বাংলা switch.
 * /privacy is the Play Store privacy URL. Text: lib/public-content.ts.
 */
export function PublicPage({ page }: { page: PublicPageName }) {
  const [lang, setLang] = usePublicLang();
  const c = PUBLIC_CONTENT[lang];

  return (
    <div className="public" lang={lang}>
      <header className="public-header">
        <Link href="/login" className="brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo-mark.png" alt="" className="brand-mark" />
          <span className="brand-text">
            <span className="brand-name">
              Medi<span className="brand-accent">-Bela</span>
            </span>
          </span>
        </Link>
        <div className="public-header-actions">
          <div className="lang-switch" role="group" aria-label="Language">
            <button className={lang === 'en' ? 'active' : ''} aria-pressed={lang === 'en'} onClick={() => setLang('en')}>
              English
            </button>
            <button className={lang === 'bn' ? 'active' : ''} aria-pressed={lang === 'bn'} onClick={() => setLang('bn')}>
              বাংলা
            </button>
          </div>
          <ThemeToggle />
        </div>
      </header>

      <main className="public-main">
        {page === 'privacy' && <Privacy c={c} />}
        {page === 'support' && <Support c={c} />}
        {page === 'about' && <About c={c} />}
      </main>

      <footer className="public-footer">
        {NAV.map((n) => (
          <Link key={n.page} href={n.href} aria-current={n.page === page ? 'page' : undefined}>
            {n.title(c)}
          </Link>
        ))}
      </footer>
    </div>
  );
}

function Privacy({ c }: { c: PublicContent }) {
  return (
    <>
      <h1>{c.privacyTitle}</h1>
      {c.privacySections.map((s) => (
        <section key={s.heading} className="card">
          <h2>{s.heading}</h2>
          <ul className="public-list">
            {s.lines.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </section>
      ))}
    </>
  );
}

function Support({ c }: { c: PublicContent }) {
  const toast = useToast();
  async function copy(number: string) {
    try {
      await navigator.clipboard.writeText(number);
      toast.success(c.copiedLabel);
    } catch {
      toast.error(number);
    }
  }

  return (
    <>
      <h1>{c.supportTitle}</h1>

      <section className="card">
        <h2>{c.contactHeading}</h2>
        <div className="contact-list">
          {SUPPORT_CONTACTS.map((n) => (
            <div key={n.display} className="contact-row">
              <span className="contact-number">{n.display}</span>
              <div className="button-row">
                <a href={n.tel} className="btn">
                  <Icon name="phone" /> {c.callLabel}
                </a>
                <a href={n.whatsapp} target="_blank" rel="noreferrer" className="btn">
                  <Icon name="chat" /> {c.whatsappLabel}
                </a>
                <button className="btn" onClick={() => copy(n.display)}>
                  <Icon name="copy" /> {c.copyLabel}
                </button>
              </div>
            </div>
          ))}
        </div>
      </section>

      <h2 className="section-title">{c.howToHeading}</h2>
      <div className="howto-grid">
        {c.howTo.map((h) => (
          <section key={h.title} className="card">
            <h3>{h.title}</h3>
            <ol className="public-list">
              {h.steps.map((s) => (
                <li key={s}>{s}</li>
              ))}
            </ol>
          </section>
        ))}
      </div>

      <h2 className="section-title">{c.faqHeading}</h2>
      <div className="card faq">
        {c.faq.map((f) => (
          <details key={f.q}>
            <summary>{f.q}</summary>
            <p>{f.a}</p>
          </details>
        ))}
      </div>
    </>
  );
}

function About({ c }: { c: PublicContent }) {
  return (
    <>
      <h1>{c.aboutTitle}</h1>
      <div className="about-statements">
        <section className="card">
          <div className="muted">{c.missionLabel}</div>
          <p className="about-statement">{c.mission}</p>
        </section>
        <section className="card">
          <div className="muted">{c.visionLabel}</div>
          <p className="about-statement">{c.vision}</p>
        </section>
      </div>
      <section className="card">
        <h2>{c.goalsHeading}</h2>
        <ul className="public-list">
          {c.goals.map((g) => (
            <li key={g}>{g}</li>
          ))}
        </ul>
      </section>
      <h2 className="section-title">{c.teamHeading}</h2>
      <div className="team-grid">
        {c.team.map((t) => (
          <section key={t.photo} className="card team-card">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={`/${t.photo}`} alt={t.name} className="team-photo" width={120} height={120} />
            <h3>{t.name}</h3>
            <div>{t.field}</div>
            <div className="muted">{t.university}</div>
            <a href={t.facebook} target="_blank" rel="noreferrer">
              {c.facebookLabel}
            </a>
          </section>
        ))}
      </div>
    </>
  );
}
