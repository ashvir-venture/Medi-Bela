# Medi-Bela

A medicine-adherence and family-care platform for Bangladesh. Patients upload a prescription, a pharmacist verifies it, and the app turns it into daily medicine reminders. Family members are alerted when a dose is missed.

## Features

- **Prescription to routine:** upload a prescription photo; a pharmacist verifies the medicines; dose schedules are generated automatically.
- **Reminders and tracking:** medicine reminders, dose status (taken / missed), and health reminders created from pharmacist-approved rules.
- **Family care:** invite family members, share medicine status, and alert them when a dose is missed.
- **Health records:** log and review health readings.
- **AI health suggestions:** an admin requests a suggestion per routine, reviews it, and decides whether to publish it. Nothing is generated or shown automatically.
- **AI assistant:** a medical-information chat with saved conversations (10 user messages each), a safety layer (no diagnosis or prescribing, emergency guidance), and read-only history.
- **Notices and push notifications:** government/health notices, an in-app inbox, and push through Firebase.
- **Account tools:** phone login, forgot password through an SMS code, change password, and account deletion.
- **Bilingual:** English and Bengali.
- **Admin web panel:** prescriptions, routines, health rules, suggestions and notices.

## Tech stack

| Part | Technology |
|---|---|
| Mobile app | Flutter, Riverpod, go_router, Dio, Drift (local SQLite), Firebase Messaging, local notifications |
| Backend API | NestJS (TypeScript), Prisma ORM, JWT, Argon2, scheduled jobs |
| Database | PostgreSQL |
| Admin panel | Next.js (React, TypeScript) |
| Services | Cloudinary (prescription images), Firebase Cloud Messaging (push), OpenAI-compatible LLM such as Groq (AI), HTTP SMS gateway (reset codes) |

## Architecture

```
 Flutter app ──┐                          ┌── Cloudinary (images)
               ├── REST /api (JWT) ──► NestJS ──► PostgreSQL (Prisma)
 Next.js admin ┘                          ├── Firebase FCM (push)
                                          ├── LLM API (assistant, suggestions)
                                          └── SMS gateway (reset codes)
```

- **Layered backend:** NestJS modules (auth, users, prescriptions, medicine schedule, family, health, notifications, assistant). Every request is JWT-authenticated and scoped to its owner. Admin and pharmacist routes are role-guarded.
- **Offline-first mobile:** the app reads from a local database and syncs changes to the server when online. The server stays the source of truth.
- **AI is advisory only:** the assistant cannot change data, and a deterministic safety filter handles emergencies and out-of-scope requests before the model is called. AI health suggestions stay drafts until an admin publishes them.
- **Background jobs:** missed-dose detection and push delivery with retries run inside the API process. Run a single instance.

## Repository layout

```
Medi-Bela/
├── backend/    NestJS API, Prisma schema and migrations
├── frontend/   Next.js admin panel
└── mobile/     Flutter app
```

See each folder for setup. The API needs the environment variables in `backend/.env.example`.
