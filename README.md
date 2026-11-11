# Medi-Bela

A medicine-adherence and family-care platform for Bangladesh. Patients upload a prescription, a pharmacist verifies it, and the app turns it into daily medicine reminders. Family members are alerted when a dose is missed.

The app opens in Bengali (English is one tap away) and follows the phone's light or dark mode.

## Features

### Medicines and reminders
- **Prescription to routine:** upload a prescription photo; a pharmacist fills in the doctor, tests and medicine lines (or rejects it with a note, and the patient re-uploads). The patient confirms, may change times, start date or meal timing, or asks the pharmacist for an edit. Dose schedules are then generated.
- **My medicines:** add your own medicines (catalog suggestions), change times, repeat every day or every N days, tag a medicine with the condition it is for, remove it.
- **Alarm-style reminders:** each dose time rings like an alarm, full screen over other apps or the lock screen when allowed, up to 4 rings with Taken (green) and Later (red). They work with the app closed and survive a reboot. Lock-screen text is neutral (no medicine names).
- **Dose outcome:** On time, Late or Missed, with a 7-day strip. A dose can be marked taken from its time until shortly before the next one.
- **Own timings:** ring gap, Later delay, number of rings and the family-alert time can be set per user (server defaults otherwise).
- **Test reminders, personal reminders and a medicine box** that counts what is left and warns before a medicine runs out.
- **Easy mode** for elders: big text, today's medicine with one big Taken button, call the caregiver, 999.

### Family care
- Invite family members, see each other's medicine status, and get an alert when a dose is missed.
- The family's **caregiver** can upload and confirm prescriptions, manage medicines, reminders and health records, and mark a dose as given for a member. Every caregiver change is labelled, audited and shown to both sides as a **change history**. A member can hide from family at any time.
- Activity feed, leave / remove, and caregiver handover.

### Health
- **My care:** pick long-term conditions (diabetes, blood pressure, heart, kidney, cancer treatment, asthma, thyroid, pregnancy); each gets a card and a page with graphs, daily habits, "How do you feel today?", when to act, tests and questions for the doctor.
- **Readings:** sugar, blood pressure, weight with BMI, temperature, insulin (with a body-map site log), sleep, water and peak flow. Targets and limits come only from the user or caregiver; crisis sheets at fixed safety levels offer 999, 16263 and "Alert family".
- **Health records:** doctor visits, upcoming tests, test results with report photos, record-only prescriptions, and a one-page **PDF for the doctor**.

### Information and help
- **AI assistant:** general health information in English or Bengali, typed or **asked by voice**. A safety layer runs first; it never diagnoses, names a medicine for the user's problem or states a dose.
- **AI health suggestions:** a pharmacist requests, reviews and publishes them; nothing is shown automatically.
- **Notices:** health notices approved by an admin, limited to divisions or nationwide, in an in-app inbox with push. A notice can be **shared with family**.
- **First-use tips** on the main screens; Privacy & terms, Support and About us in the app and on the web.

### Accounts and management
- Phone sign-up and login, SMS password reset, change password, pause (deactivate) or delete the account (personal data erased).
- **Management web panel:** pharmacists handle the prescription queue, doctors, medicines, health rules, AI suggestions and notice drafts; admins see analytics, users (ban / unban), notices and the audit log.

## Tech stack

| Part | Technology |
|---|---|
| Mobile app | Flutter, Riverpod, go_router, Dio, Drift (local SQLite), Firebase Messaging, local notifications, pdf + printing, speech_to_text |
| Backend API | NestJS (TypeScript), Prisma ORM, JWT, Argon2, scheduled jobs, rate limiting |
| Database | PostgreSQL |
| Admin panel | Next.js (React, TypeScript) |
| Services | Cloudinary (private images), Firebase Cloud Messaging (push), OpenAI-compatible LLM such as Groq (AI), HTTP SMS gateway (reset codes) |

## Architecture

```
 Flutter app ──┐                          ┌── Cloudinary (images)
               ├── REST /api (JWT) ──► NestJS ──► PostgreSQL (Prisma)
 Next.js admin ┘                          ├── Firebase FCM (push)
                                          ├── LLM API (assistant, suggestions)
                                          └── SMS gateway (reset codes)
```

- **Layered backend:** NestJS modules (auth, users, prescriptions, medicine schedule, family, health, care, records, notices, notifications, assistant, catalog, admin, audit). Every request is JWT-authenticated and scoped to its owner; staff routes are role-guarded; caregiver access goes through one check.
- **Offline-first mobile:** the app reads from a local database, schedules reminders on the phone, and syncs with the server when online. The server stays the source of truth.
- **AI is advisory only:** a deterministic safety filter runs before the model, and AI suggestions stay drafts until a pharmacist publishes them.
- **Privacy:** prescription and report photos are private with expiring links; push and lock-screen texts never name medicines or readings; health data is never logged.
- **Background jobs:** missed-dose alerts, backstop pushes, rolling dose generation, scheduled notices and test reminders run inside the API process. Run a single instance.

## Repository layout

```
Medi-Bela/
├── backend/    NestJS API, Prisma schema, migrations and pending SQL
├── frontend/   Next.js management panel
├── mobile/     Flutter app (Android)
└── docs/       release runbooks and the public page texts
```

## Getting started

```bash
# Backend (needs PostgreSQL)
cd backend && npm install && cp .env.example .env   # fill in the values
npm run prisma:generate && npm run prisma:migrate && npm run prisma:seed
npm run start:dev                                   # http://localhost:3001/api

# Management panel
cd frontend && npm install && cp .env.example .env.local
npm run dev

# Mobile app
cd mobile && flutter pub get && flutter run
```

Tests: `npm test` in `backend/` (DB-backed specs run only with `TEST_DATABASE_URL` pointing at a disposable database), `flutter test` in `mobile/`.

## Status

Version 0.1.0. All planned feature rounds are code complete and tested. Next: testing on real phones and the Play Store release (upload key, Data safety form).
