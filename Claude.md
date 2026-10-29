1. Project overview

Medi-Bela is a medicine-adherence and family-care platform for Bangladesh. Patients upload a prescription, a pharmacist verifies it, and the app turns it into daily medicine reminders; family members are alerted when a dose is missed. Built for patients, their families, pharmacists, and admins.

0.1.0 does:

Prescription photo upload -> pharmacist prepares it (doctor, visit, diagnosis, tests, structured medicine lines) or rejects it with feedback -> patient confirms -> auto-generated dose schedules (the Confirm screen is Round 6)
Re-upload: a rejected prescription shows the pharmacist's note and a Re-upload button in the app; the new upload is linked to the rejected one
Medicine reminders, dose status (taken / missed), health reminders from pharmacist-approved rules
Reminder check (Android): exact alarms when "Alarms & reminders" is allowed, inexact fallback otherwise; warning banner on Home / Today's medicine; reminders survive reboot
Alarm-style medicine reminders: one per scheduled time, rings with the alarm tone for 2 minutes (respects silent), silent copy after, repeat at +30; Done (marks the whole group taken) and Later (30 min, twice at most) work with the app closed; neutral lock-screen text (count + time, no names)
Medicine-reminders switch (off = no reminders, no backstop, no family missed-dose alerts) and notices switch (off = notices not pushed); server backstop push to the patient at +30; family alert at +62
Inbox tabs: Personal, Family, General
Family care: invites, shared medicine status, missed-dose alerts
Health records: log and review readings
AI health suggestions: admin requests per routine, reviews, then publishes (never automatic)
AI assistant: medical-info chat, saved conversations (10 user messages each), safety layer (no diagnosis/prescribing, emergency guidance), read-only history
Notices, in-app inbox, push via Firebase
Account tools: phone login, SMS-code password reset, change password, account deletion
Global API rate limit (per user signed in, per IP on public routes); private prescription images served via expiring signed links
Bilingual: English and Bengali
Staff web panel (left sidebar, responsive): pharmacists at / (dashboard, prescription queue + form, doctors, medicines, health rules, notice drafts); admin at /super-control-007 (dashboard, read-only prescriptions, routines, AI suggestions, notices with publish)
2. Tech stack
Part	Technology (from manifests)
Backend backend/	NestJS ^11.2 (TypeScript ^6.0), Prisma ^6.19, Passport-JWT, Argon2, class-validator/class-transformer, @nestjs/schedule, @nestjs/throttler ^6.7, helmet, multer, Cloudinary, firebase-admin ^13. Tests: Jest ^30 + ts-jest + supertest. Lint: oxlint. Format: Prettier ^3.4
Database	PostgreSQL (Prisma migrations in backend/prisma/migrations)
Admin frontend/	Next.js ^15 (App Router), React ^18.3, TypeScript ^5.5. No UI/test libraries. Package name carebridge-admin, v0.1.0
Mobile mobile/	Flutter, Dart SDK ^3.13.2, flutter_riverpod ^2.6, go_router ^18, dio ^5.11, drift ^2.34 (+ drift_dev, build_runner), flutter_secure_storage ^11 (tokens), flutter_local_notifications ^19, firebase_messaging ^17, flutter_lints ^6
Services	Cloudinary (images), Firebase FCM (push), OpenAI-compatible LLM via LLM_API_BASE_URL (plain HTTP, no SDK), HTTP SMS gateway (src/auth/sms.service.ts)

Versions differ per part (backend 0.0.1, admin 0.1.0, mobile 1.0.0+1). [ASK] which one is "0.1.0".

3. Commands

Run each from its own folder. Package manager is npm (package-lock.json in backend and frontend).

Backend (cd backend)
bash
npm install
cp .env.example .env              # fill in values (see section 7)
npm run prisma:generate           # prisma generate
npm run prisma:migrate            # prisma migrate dev (creates/applies migrations)
npm run prisma:seed               # ts-node prisma/seed.ts (admin; plus a pharmacist when SEED_PHARMACIST_PHONE/PASSWORD are set)
npm run start:dev                 # nest start --watch (default PORT 3001, prefix /api)
npm run lint                      # oxlint src/ test/
npm run format                    # prettier --write src/** test/**
npm test                          # jest (*.spec.ts, unit; DB specs auto-skip)
npm run test:cov                  # coverage
npm run test:e2e                  # jest --config test/jest-e2e.json (*.e2e-spec.ts)
npm run build                     # tsc -p tsconfig.build.json --outDir dist
npm run start:prod                # node dist/main.js
npm run push:check                # ts-node scripts/check-push.ts (FCM sanity check)

DB-backed integration specs (*.int.spec.ts, src/e2e/) only run when TEST_DATABASE_URL is set. They TRUNCATE tables: use a disposable Postgres only, never a real DB. The test helper also expects phase4a_extra.sql applied (see backend/migrations_phase4a/).

Admin panel (cd frontend)
bash
npm install
cp .env.example .env.local        # NEXT_PUBLIC_API_BASE_URL=http://localhost:3001/api
npm run dev
npm run build
npm run start
npm run lint                      # next lint

No test script exists. next lint has no ESLint dependency or config in package.json [ASK] whether lint is expected to work here.

Mobile (cd mobile)
bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift/json codegen (app_database.g.dart is committed)
flutter run
flutter analyze                   # flutter_lints via analysis_options.yaml
flutter test                      # mobile/test: scheduler, sync queue, inbox tabs (Drift in-memory)
flutter build apk                 # or: flutter build appbundle

Before calling any task done: lint, tests and build pass for every part touched.

4. Folder structure
Medi-Bela/
├── backend/
│   ├── prisma/            schema.prisma, seed.ts, migrations/
│   ├── migrations_phase4a/ raw SQL extras (phase4a_*.sql)
│   ├── scripts/           check-push.ts
│   ├── test/              app.e2e-spec.ts, jest-e2e.json
│   └── src/
│       ├── main.ts, app.module.ts
│       ├── auth/ users/ prescriptions/ medicine-schedule/ family/
│       │   health/ notifications/ notices/ assistant/ admin/
│       │   catalog/ (doctors, medicines, tests) lookups/ (dropdown data) audit/ (AuditService)
│       │   (each: *.module/controller/service.ts, dto/, __tests__/, sometimes lib/)
│       ├── common/        constants/ decorators/ filters/ guards/ interfaces/ rate-limit/ utils/ (cursor-pagination.ts)
│       ├── prisma/        PrismaService
│       ├── test-utils/    test-prisma.ts (real-DB helper)
│       └── e2e/           mvp-flow.int.spec.ts
├── frontend/src/
│   ├── app/               login, page.tsx (redirect by role)
│   │   ├── (pharmacist)/  layout (PHARMACIST gate + sidebar): dashboard, prescriptions[/id],
│   │   │                  doctors[/id], medicines[/id], health-rules, notices
│   │   └── super-control-007/  layout (ADMIN gate + sidebar): dashboard, prescriptions (read-only),
│   │                      routines, health-suggestions, notices
│   ├── components/        app-shell (sidebar), topbar (page header), autosuggest, pager,
│   │                      catalog-list, medicine-form, status-badge, icons,
│   │                      prescriptions/ (queue, workspace), notices/ (shared by both areas)
│   └── lib/               api-client.ts, use-require-auth.ts (useRequireRole), paths.ts (ADMIN_BASE)
└── mobile/lib/
    ├── core/              constants, database (Drift), localization, network, storage, theme, utils
    ├── features/<name>/   data/ domain/ presentation/
    │                      (assistant, auth, diabetes, family, health, home, inbox,
    │                       medicine_schedule, notices, prescription, profile, reminders)
    ├── notifications/  providers/  router/  sync/  widgets/
    mobile/test/           notifications/, sync/, inbox/, prescription/ (flutter_test, no extra deps)
5. Architecture to preserve
Flutter app ──┐                          ┌── Cloudinary
              ├── REST /api (JWT) ──► NestJS ──► PostgreSQL (Prisma)
Next.js admin ┘                          ├── Firebase FCM
                                         ├── LLM API
                                         └── SMS gateway
Layered NestJS modules. Every request is JWT-authenticated and owner-scoped; admin/pharmacist routes are role-guarded (common/guards, @Roles, @Public, @CurrentUser).
Offline-first mobile: reads from local Drift DB, syncs when online. Server is the source of truth. Tokens live in flutter_secure_storage, never SQLite.
AI is advisory only: deterministic safety filter (assistant/assistant-safety.ts) runs before the model; AI suggestions stay drafts until an admin publishes.
Background jobs (missed-dose detection, push dispatch) run inside the API process. Run a single instance; toggle via MISSED_DOSE_JOB_ENABLED / PUSH_DISPATCH_JOB_ENABLED.
Rate limit: @nestjs/throttler as the last APP_GUARD (after JWT and roles), one in-memory bucket per user id (signed in) or client IP (@Public routes), 429 + Retry-After; /health is @SkipThrottle; off under Jest. Config in common/rate-limit/rate-limit.config.ts. Single instance only (in-memory counters).
Mobile sync queue treats 429 as "pause until Retry-After", never as a failed attempt (a give-up would revert a dose marked taken).
Prescription images: new uploads are Cloudinary `authenticated` assets; the DB stores the unsigned URL as a reference and PrescriptionImageUrlInterceptor swaps it for a 1-hour signed download link in every PrescriptionsController response. Older `upload` (public) images pass through unchanged.
Reminders: NotificationScheduler asks the gateway whether exact alarms are allowed on every reconcile and re-registers all reminders once per process and whenever that answer changes (force-stop or permission revoke wipes OS alarms). AndroidManifest declares the plugin's boot/scheduled receivers; MainActivity hosts the com.carebridge.app/reminder_status channel (channel blocked, battery optimization, open settings).
Notices: pharmacists can draft/edit; only ADMIN can publish.
Staff roles: pharmacists prepare/reject prescriptions and create/edit doctors, medicines and tests (PHARMACIST only); admins read them. Admin dashboard, routines panel and AI suggestions are ADMIN only; pharmacists have GET /pharmacist/dashboard. Health rules and notice drafts stay open to both. The panel's role layouts read the role from GET /users/me; the backend guards are the real check.
Catalog: a medicine typed on a line without a catalog pick becomes a stub Medicine (brand name only, matched case-insensitively) for a pharmacist to complete; a typed doctor creates a Doctor row (same BMDC number = same doctor); "Not applicable" creates none. Autosuggest is prefix search via lower(col) LIKE 'x%' on the text_pattern_ops indexes in pending SQL 004 (not in schema.prisma).
Prescription statuses: PENDING -> REJECTED or AWAITING_CONFIRMATION -> ACTIVE -> ENDED. Completing (pharmacist) sets AWAITING_CONFIRMATION and creates no routine; PrescriptionsService.activate() (AWAITING_CONFIRMATION -> ACTIVE, routines + doses + health rules) has no route until the Round 6 Confirm screen, so new prescriptions get no reminders until then. A re-upload carries previousPrescriptionId (only to the uploader's own REJECTED prescription). Medicine lines carry a revision; prescriptions have currentRevision / pendingRevision for a pharmacist edit made after activation.
Rolling doses: routine generation creates doses only ROLLING_HORIZON_DAYS (14) ahead and stores scheduleTimes + generatedUntil on the routine; RollingDoseJob (hourly, ROLLING_DOSE_JOB_ENABLED) extends active routines with a compare-and-set on generatedUntil. Continuous lines have no endDate. Routines from before Round 4 have no scheduleTimes and are left alone.
Address: users.divisionId/districtId/upazilaId with composite foreign keys (districts(id, divisionId), upazilas(id, districtId)) and CHECK constraints, so a level can't belong to another parent or skip the one above.
Privacy flag ("Hide from family", off by default) is users.profileVisibleToFamily stored inverted; hidden users are hidden from every family member, owner included, and get no family missed-dose alerts.
AuditLog: append-only (actor, subject user, action, entity, before/after JSON) via AuditService.record (pass the transaction client); never store secrets, phone numbers or rejection text in it. Written today: prescription.prepare/reject/confirm, doctor.create/update, medicine.create/update.
Pagination: common/utils/cursor-pagination.ts (keyset on createdAt DESC, id DESC; ADMIN_PAGE_SIZE 20, USER_PAGE_SIZE 10).
Medicine reminder groups (NotificationScheduler): doses due at the same time share one group; ScheduledMedicineNotifications rows are keyed `grp:<T ms>:<hash of dose ids>` (group), `snz:<group key>` (pending Later: notificationId = stage, scheduledAt = ring time) and `health:<id>`, so the Drift schema did not change. Stage 0 at T, stage 1 at T+30 or after the first Later, stage 2 only after a second Later (no Later button). Ringing uses channel `medicine_alarm` (alarm tone, FLAG_INSISTENT, timeoutAfter 2 min) and a silent copy on `medicine_reminders` at +2 min. Payload JSON {type: MEDICINE_REMINDER, at, stage}.
Background work (notifications/reminder_actions.dart): Done/Later and the FCM backstop run in a background isolate when the app is closed, through a ProviderContainer opened by openBackgroundContainer(); main() owns the app's ProviderContainer (UncontrolledProviderScope) so foreground actions use the same services. AppDatabase opens with shareAcrossIsolates. Done tries to sync immediately.
Reminder switch: the account owns medicineRemindersEnabled; SessionServices mirrors it into SharedPreferences (ReminderPreference) so the scheduler obeys it offline and in background isolates.
Backstop push: MissedDoseAlertService.sendBackstops creates one MEDICINE_REMINDER notification per (user, scheduled time) with untaken doses at +30 min (patient only, reminders on), relatedEntityId `backstop:<iso>`, sent data-only; the app shows it as the group's stage-1 reminder (same id, replaces the local repeat) or drops it when its local cache shows the doses taken. Push rules: NOTICE needs noticesEnabled, MEDICINE_REMINDER needs medicineRemindersEnabled, everything needs notificationsEnabled.
Missed-dose grace default is 62 minutes (DOSE_MISSED_GRACE_MINUTES); family alerts also require the patient's medicineRemindersEnabled.
6. Coding conventions

Match the surrounding file. Observed in the code:

Backend: Nest file naming kebab-case.type.ts (*.module|controller|service|dto.ts); PascalCase classes, camelCase members. Global ValidationPipe with whitelist, forbidNonWhitelisted, transform: every request body needs a DTO with class-validator decorators, and unknown fields are rejected. Global prefix api. Errors use Nest HTTP exceptions, formatted by common/filters/http-exception.filter.ts. Prisma only through PrismaService. Config via @nestjs/config / .env.
Backend tests: colocated __tests__/ or *.spec.ts beside the file; DB-backed ones use makeTestPrisma() and skip without TEST_DATABASE_URL.
Admin: App Router, one page.tsx per route, shared pieces in components/, all HTTP through lib/api-client.ts. Each area's layout gates by role (useRequireRole) and renders AppShell; pages render <Topbar title> as their heading. Admin links use ADMIN_BASE from lib/paths.ts. Plain CSS in app/globals.css (no UI library).
Mobile: feature-first data/domain/presentation layers; Riverpod providers (providers/core_providers.dart), go_router (router/app_router.dart), Dio for HTTP, Drift for local data. UI strings live in core/localization/app_strings.dart; add both English and Bengali for every string.
Database: during development change only backend/prisma/schema.prisma (no new migration files) and add the matching SQL as the next numbered file in backend/prisma/pending-sql/ (listed under "Database changes (pending SQL for Neon)" in plan.md); the owner runs them in the Neon SQL editor at the end of development. Generate the SQL with `prisma migrate diff --from-schema-datamodel <previous schema> --to-schema-datamodel prisma/schema.prisma --script`, then hand-fix data conversions (enum value changes) and add what Prisma can't express (CHECK constraints). Verify on a disposable Postgres (all migrations + pending files, then diff against the schema). Never edit an existing applied migration.
Dropdowns: every dropdown reads a lookup table (genders, divisions, districts, upazilas, doctor_specialties, medicine_forms, medicine_categories, meal_timings, test_categories), English only, edited by the owner in the database. No hard-coded option lists.
Medical privacy: never log prescriptions, readings, phone numbers, tokens, or passwords. Passwords use Argon2. Notifications that name medicines or readings need a neutral public (lock-screen) version; details appear only after unlock (shared phones are common).
AI safety: never bypass the safety filter, auto-publish AI output, or add diagnosis/prescribing behavior.
Secrets: .env only; keep .env.example current; never commit real keys.
7. Environment variables (backend/.env.example)

DATABASE_URL, PORT, CORS_ORIGINS, CLOUDINARY_CLOUD_NAME|API_KEY|API_SECRET, LLM_API_BASE_URL|LLM_API_KEY|LLM_MODEL, JWT_ACCESS_SECRET (required, app won't start without it), JWT_ACCESS_EXPIRES_IN, PUSH_TOKEN_ENC_KEY (required, openssl rand -base64 32), one of FIREBASE_SERVICE_ACCOUNT_BASE64|JSON / GOOGLE_APPLICATION_CREDENTIALS (without one, push is disabled), APP_UTC_OFFSET_MINUTES, DOSE_MISSED_GRACE_MINUTES (default 62; a deployed value overrides it), MISSED_ALERT_MAX_AGE_MINUTES, MISSED_DOSE_JOB_ENABLED, ROLLING_DOSE_JOB_ENABLED, PUSH_DISPATCH_JOB_ENABLED, TRUST_PROXY, RATE_LIMIT_ENABLED|RATE_LIMIT_USER_PER_MINUTE (120)|RATE_LIMIT_IP_PER_MINUTE (60), SMS_API_URL|SMS_API_KEY|SMS_SENDER_ID, SEED_ADMIN_PHONE|SEED_ADMIN_PASSWORD, SEED_PHARMACIST_PHONE|SEED_PHARMACIST_PASSWORD (seed only). Admin: NEXT_PUBLIC_API_BASE_URL.

8. Rules and don'ts
Never break existing things without asking first (API contracts, DB schema, Drift schema, existing behavior).
Don't add dependencies without asking. Name the package, why, and alternatives.
Always add tests for bug fixes (fails before the fix, passes after).
Don't assume anything. If confused, ask me.
Keep current architecture and conventions; keep changes small and scoped; no drive-by refactors.
Don't run destructive DB commands (migrate reset, drops, TRUNCATE-based tests) against anything but a disposable DB.
Don't run more than one API instance.
9. Known issues / open questions (do not fix without asking)
[ASK] API prefix mismatch: main.ts uses prefix api, but src/app.e2e.int.spec.ts sets api/v1 and calls /api/v1/auth/register; controllers have no versioning. Admin default base URL is /api.
[ASK] Stray files committed: mobile/body.json, backend/src/.env.example, backend/src/package.json.txt, backend/src/schema.txt. Possibly leftovers.
[ASK] Version numbers differ across parts (see section 2).
Mobile has a diabetes feature folder with only presentation/, not listed in the README.
Admin has no tests. Mobile tests cover the reminder scheduler, sync queue, inbox tabs and the re-upload link, not widgets or background isolates.
flutter_local_notifications 19.5 has no notification public version, so medicine reminders always use neutral text (count + time) instead of names-after-unlock.
mobile/.gitignore: the Xcode rules `profile` and `**/*sync/` are scoped to ios/ (unscoped, they hid lib/features/profile/, lib/sync/ and android/app/src/profile/ from git). Keep new Xcode-template rules under ios/.
[ASK] Pre-existing failing unit tests: src/app.controller.spec.ts expects service name "carebridge-backend" (controller says "medi-bela backend"); src/health/__tests__/ai-suggestion.service.spec.ts prompt assertion.
[ASK] Stale DB-backed integration tests (seen when run against a disposable Postgres): mvp-flow.int.spec's auth sweep and password-length check, and admin.int.spec's assistant endpoint (404).
Stray tsc output (*.js/*.d.ts next to sources, backend/jest.config.js) is gitignored; if it reappears, delete it: a second jest config breaks `npm test`.
Release build is signed with the debug key (android/app/build.gradle.kts); needs a real upload key before Play Store.
10. Current work

Tracked in @PLAN.md.

11. Maintenance rule

With every development phase: update CLAUDE.md (existing work: features, commands, structure, conventions) and PLAN.md (future work) before calling the phase done.