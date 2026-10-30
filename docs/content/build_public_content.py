"""Builds the Privacy & terms / Support / About us content for the panel and
the app from docs/content/public-pages.json (one source, both languages).

Run from the repository root:  python docs/content/build_public_content.py
Writes:
  frontend/src/lib/public-content.ts
  mobile/lib/features/help/domain/help_content.dart
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
data = json.load(open(os.path.join(ROOT, 'docs', 'content', 'public-pages.json'), encoding='utf-8'))
HEADER = 'Generated from docs/content/public-pages.json by docs/content/build_public_content.py. Do not edit.'

# ---- TypeScript ------------------------------------------------------------------
content = {k: v for k, v in data.items() if not k.startswith('_')}
ts = f"""// {HEADER}

export type PublicLang = 'en' | 'bn';

export interface PublicContent {{
  privacyTitle: string;
  privacySections: {{ heading: string; lines: string[] }}[];
  supportTitle: string;
  howToHeading: string;
  howTo: {{ title: string; steps: string[] }}[];
  faqHeading: string;
  faq: {{ q: string; a: string }}[];
  contactHeading: string;
  callLabel: string;
  whatsappLabel: string;
  copyLabel: string;
  copiedLabel: string;
  aboutTitle: string;
  missionLabel: string;
  mission: string;
  visionLabel: string;
  vision: string;
  goalsHeading: string;
  goals: string[];
  teamHeading: string;
  facebookLabel: string;
  team: {{ photo: string; name: string; field: string; university: string; facebook: string }}[];
}}

export const PUBLIC_CONTENT: Record<PublicLang, PublicContent> = {json.dumps({'en': content['en'], 'bn': content['bn']}, ensure_ascii=False, indent=2)};

export const SUPPORT_CONTACTS: {{ display: string; tel: string; whatsapp: string }}[] = {json.dumps(content['contacts'], ensure_ascii=False, indent=2)};
"""
open(os.path.join(ROOT, 'frontend', 'src', 'lib', 'public-content.ts'), 'w', encoding='utf-8', newline='\n').write(ts)


# ---- Dart ------------------------------------------------------------------------------
def d(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def dlist(items, fn, indent):
    pad = ' ' * indent
    return '[\n' + ''.join(f'{pad}  {fn(i)},\n' for i in items) + f'{pad}]'


def lang(c, indent=2):
    p = ' ' * indent
    return f"""HelpContent(
{p}  privacyTitle: {d(c['privacyTitle'])},
{p}  privacySections: {dlist(c['privacySections'], lambda s: f"HelpSection({d(s['heading'])}, {dlist(s['lines'], d, indent + 4)})", indent + 2)},
{p}  supportTitle: {d(c['supportTitle'])},
{p}  howToHeading: {d(c['howToHeading'])},
{p}  howTo: {dlist(c['howTo'], lambda h: f"HelpSection({d(h['title'])}, {dlist(h['steps'], d, indent + 4)})", indent + 2)},
{p}  faqHeading: {d(c['faqHeading'])},
{p}  faq: {dlist(c['faq'], lambda f: f"HelpFaq({d(f['q'])}, {d(f['a'])})", indent + 2)},
{p}  contactHeading: {d(c['contactHeading'])},
{p}  callLabel: {d(c['callLabel'])},
{p}  whatsappLabel: {d(c['whatsappLabel'])},
{p}  copyLabel: {d(c['copyLabel'])},
{p}  copiedLabel: {d(c['copiedLabel'])},
{p}  aboutTitle: {d(c['aboutTitle'])},
{p}  missionLabel: {d(c['missionLabel'])},
{p}  mission: {d(c['mission'])},
{p}  visionLabel: {d(c['visionLabel'])},
{p}  vision: {d(c['vision'])},
{p}  goalsHeading: {d(c['goalsHeading'])},
{p}  goals: {dlist(c['goals'], d, indent + 2)},
{p}  teamHeading: {d(c['teamHeading'])},
{p}  facebookLabel: {d(c['facebookLabel'])},
{p}  team: {dlist(c['team'], lambda t: f"HelpTeamMember(photo: {d(t['photo'])}, name: {d(t['name'])}, field: {d(t['field'])}, university: {d(t['university'])}, facebook: {d(t['facebook'])})", indent + 2)},
{p})"""


dart = f"""// {HEADER}
// ignore_for_file: lines_longer_than_80_chars

import 'help_models.dart';

const helpContentEn = {lang(content['en'], 0)};

const helpContentBn = {lang(content['bn'], 0)};

const supportContacts = {dlist(content['contacts'], lambda c: f"SupportContact(display: {d(c['display'])}, tel: {d(c['tel'])}, whatsapp: {d(c['whatsapp'])})", 0)};
"""
path = os.path.join(ROOT, 'mobile', 'lib', 'features', 'help', 'domain')
os.makedirs(path, exist_ok=True)
open(os.path.join(path, 'help_content.dart'), 'w', encoding='utf-8', newline='\n').write(dart)
print('wrote public-content.ts and help_content.dart')
