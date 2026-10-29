1. Project overview

Medi-Bela is a medicine-adherence and family-care platform for Bangladesh. Patients upload a prescription, a pharmacist verifies it, and the app turns it into daily medicine reminders; family members are alerted when a dose is missed. Built for patients, their families, pharmacists, and admins.

0.1.0 does:

Prescription photo upload -> pharmacist prepares it (doctor, visit, diagnosis, tests, structured medicine lines) or rejects it with feedback -> patient confirms ("Confirm or Edit": may change dose times, start date, meal timing, or remove a line) -> auto-generated dose schedules
My medicines: patients add their own medicines (catalog suggestions, "Self-added"), change times/meal timing of a pharmacist's medicine or anything on a self-added one ("Edited by you"), and remove medicines
Caregiver (the family's CAREGIVER, formerly "owner"): can upload and confirm prescriptions and manage medicines for any member who doesn't hide from family; every such item shows "by caregiver", is audited, and the member gets a neutral push (Family inbox tab). Only the patient marks their own doses taken or Later; the caregiver views doses and gets missed-dose alerts like any family member
Signup requires date of birth, gender, division, district and upazila (from the lookup tables); "Edit your details" page in Profile
Larger text and tap targets app-wide; user lists show 10 rows with "Load more"
Re-upload: a rejected prescription shows the pharmacist's note and a Re-upload button in the app; the new upload is linked to the rejected one
Medicine reminders, dose status (taken / missed), health reminders from pharmacist-approved rules
Reminder check (Android): exact alarms when "Alarms & reminders" is allowed, inexact fallback otherwise; warning banner on Home / Today's medicine; reminders survive reboot
Alarm-style medicine reminders: one per scheduled time, rings with the alarm tone for 2 minutes (respects silent), silent copy after, repeat at +30; Done (marks the whole group taken) and Later (30 min, twice at most) work with the app closed; neutral lock-screen text (count + time, no names)
Medicine-reminders switch (off = no reminders, no backstop, no family missed-dose alerts) and notices switch (off = notices not pushed); server backstop push to the patient at +30; family alert at +62
Inbox tabs: Personal, Family, General
Family care: invites (with a warning that the inviter becomes caregiver), shared medicine status, missed-dose alerts, caregiver actions
Health records: log and review readings
AI health suggestions: admin requests per routine, reviews, then publishes (never automatic)
AI assistant: medical-info chat, saved conversations (10 user messages each), safety layer (no diagnosis/prescribing, emergency guidance), read-only history
Notices, in-app inbox, push via Firebase. Notices: pharmacist drafts and submits, admin approves or sends back with a note (admin's own publish directly); optional source; scheduled start; limited to divisions or nationwide (list and push follow the same rule); the app shows the source, opens a notice from its push/inbox entry, and the General tab has an "All notices" shortcut
Account tools: phone login, SMS-code password reset, change password, account deletion
Global API rate limit (per user signed in, per IP on public routes); private prescription images served via expiring signed links
Bilingual: English and Bengali; an English | বাংলা switcher on every sign-in screen (login, register, forgot/reset password), uploaded to the account after sign-in like the Profile choice
Dark mode: the app follows the phone or Profile → Appearance (System / Light / Dark, this device only); the staff panel follows the computer or the sidebar / login Theme control (this browser only)
Staff web panel (left sidebar, responsive): pharmacists at / (dashboard, prescription queue + form, doctors, medicines, health rules, notice drafts); admin at /super-control-007 (dashboard with analytics: users by division/district, gender and age, families, incomplete doctor/medicine counts, doctors and medicines with the most patients (full rankings paged 20 at a time); read-only prescriptions, doctors and medicines with "Created by" and patient counts; routines, AI suggestions, notices with publish)
2. Tech stack
Part	Technology (from manifests)
Backend backend/	NestJS ^11.2 (TypeScript ^6.0), Prisma ^6.19, Passport-JWT, Argon2, class-validator/class-transformer, @nestjs/schedule, @nestjs/throttler ^6.7, helmet, multer, Cloudinary, firebase-admin ^13. Tests: Jest ^30 + ts-jest + supertest. Lint: oxlint. Format: Prettier ^3.4
Database	PostgreSQL (Prisma migrations in backend/prisma/migrations)
Admin frontend/	Next.js ^15 (App Router), React ^18.3, TypeScript ^5.5. No UI/test libraries. Package name carebridge-admin, v0.1.0
Mobile mobile/	Flutter, Dart SDK ^3.13.2, flutter_riverpod ^2.6, go_router ^18, dio ^5.11, drift ^2.34 (+ drift_dev, build_runner), flutter_secure_storage ^11 (tokens), flutter_local_notifications ^19, firebase_messaging ^17, flutter_lints ^6
Services	Cloudinary (images), Firebase FCM (push), OpenAI-compatible LLM via LLM_API_BASE_URL (plain HTTP, no SDK), HTTP SMS gateway (src/auth/sms.service.ts)

All parts are version 0.1.0 (backend and admin package.json, mobile pubspec 0.1.0+1).

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
LOAD_TEST_DATABASE_URL=postgresql://postgres@localhost:<port>/<db> npx ts-node scripts/load-test.ts --patients 1000 [--history-days 30] [--out report.md]
                                  # synthetic data + job/read timings + index scans; TRUNCATES the target, localhost only

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
├── docs/release/          deploy-runbook (fresh Neon + Render), backup-restore, load-test-and-index-audit, android-release-notes
├── backend/
│   ├── prisma/            schema.prisma, seed.ts, migrations/
│   ├── migrations_phase4a/ raw SQL extras (phase4a_*.sql)
│   ├── scripts/           check-push.ts, load-test.ts
│   ├── test/              app.e2e-spec.ts, jest-e2e.json
│   └── src/
│       ├── main.ts, app.module.ts
│       ├── auth/ users/ prescriptions/ medicine-schedule/ family/
│       │   health/ notifications/ notices/ assistant/ admin/
│       │   catalog/ (doctors, medicines, tests) lookups/ (dropdown data) audit/ (AuditService)
│       │   (each: *.module/controller/service.ts, dto/, __tests__/, sometimes lib/)
│       ├── common/        constants/ decorators/ filters/ guards/ interfaces/ rate-limit/ utils/ (cursor-pagination.ts, ttl-cache.ts)
│       ├── prisma/        PrismaService
│       ├── test-utils/    test-prisma.ts (real-DB helper)
│       └── e2e/           mvp-flow.int.spec.ts
├── frontend/src/
│   ├── app/               login, page.tsx (redirect by role)
│   │   ├── (pharmacist)/  layout (PHARMACIST gate + sidebar): dashboard, prescriptions[/id],
│   │   │                  doctors[/id], medicines[/id], health-rules, notices
│   │   └── super-control-007/  layout (ADMIN gate + sidebar): dashboard, prescriptions (read-only),
│   │                      doctors[/id], medicines[/id] (read-only), analytics/top-doctors|top-medicines,
│   │                      routines, health-suggestions, notices
│   ├── components/        app-shell (sidebar), topbar (page header), autosuggest, pager,
│   │                      catalog-list, medicine-form, status-badge, icons, analytics (dashboard section),
│   │                      ranked-page, record-view (read-only record), created-by,
│   │                      prescriptions/ (queue, workspace), notices/ (shared by both areas)
│   └── lib/               api-client.ts, use-require-auth.ts (useRequireRole), paths.ts (ADMIN_BASE)
└── mobile/lib/
    ├── core/              constants, database (Drift), localization, network, storage, theme, utils
    ├── features/<name>/   data/ domain/ presentation/
    │                      (assistant, auth, diabetes, family, health, home, inbox,
    │                       medicine_schedule, notices, prescription, profile, reminders)
    ├── notifications/  providers/  router/  sync/  widgets/
    mobile/test/           notifications/, sync/, inbox/, prescription/, medicine_schedule/ (flutter_test, no extra deps)
5. Architecture to preserve
Flutter app ──┐                          ┌── Cloudinary
              ├── REST /api (JWT) ──► NestJS ──► PostgreSQL (Prisma)
Next.js admin ┘                          ├── Firebase FCM
                                         ├── LLM API
                                         └── SMS gateway
Layered NestJS modules. Every request is JWT-authenticated and owner-scoped; admin/pharmacist routes are role-guarded (common/guards, @Roles, @Public, @CurrentUser).
Offline-first mobile: reads from local Drift DB, syncs when online. Server is the source of truth. Tokens live in flutter_secure_storage, never SQLite.
AI is advisory only: deterministic safety filter (assistant/assistant-safety.ts) runs before the model; AI suggestions stay drafts until an admin publishes.
Background jobs (missed-dose detection, push dispatch, rolling doses, scheduled notices) run inside the API process. Run a single instance; toggle via MISSED_DOSE_JOB_ENABLED / PUSH_DISPATCH_JOB_ENABLED / ROLLING_DOSE_JOB_ENABLED / NOTICE_SCHEDULE_JOB_ENABLED.
Rate limit: @nestjs/throttler as the last APP_GUARD (after JWT and roles), one in-memory bucket per user id (signed in) or client IP (@Public routes), 429 + Retry-After; /health is @SkipThrottle; off under Jest. Config in common/rate-limit/rate-limit.config.ts. Single instance only (in-memory counters).
Mobile sync queue treats 429 as "pause until Retry-After", never as a failed attempt (a give-up would revert a dose marked taken).
Prescription images: new uploads are Cloudinary `authenticated` assets; the DB stores the unsigned URL as a reference and PrescriptionImageUrlInterceptor swaps it for a 1-hour signed download link in every PrescriptionsController response. Older `upload` (public) images pass through unchanged.
Reminders: NotificationScheduler asks the gateway whether exact alarms are allowed on every reconcile and re-registers all reminders once per process and whenever that answer changes (force-stop or permission revoke wipes OS alarms). AndroidManifest declares the plugin's boot/scheduled receivers; MainActivity hosts the com.carebridge.app/reminder_status channel (channel blocked, battery optimization, open settings).
Notices (NoticesService): DRAFT -submit (PHARMACIST)-> PENDING_APPROVAL -publish (ADMIN, = approve)-> PUBLISHED; withdraw (PHARMACIST) and send-back with a required note (ADMIN, stored in notices.reviewNote, cleared on resubmit/publish) return it to DRAFT; an admin may publish any DRAFT directly; PUBLISHED <-> ARCHIVED (ADMIN). Pharmacists edit/delete only DRAFTs. A publish with a future startsAt leaves publishedAt null (scheduled, hidden, not pushed); NoticeScheduleJob (every minute) sets publishedAt with a compare-and-set and pushes once. Users see PUBLISHED with publishedAt <= now, not expired, audience-matched, and nationwide (no notice_divisions rows) or their own division; pushes use the same rule (staff have no division and always get them). Approve/publish/submit/withdraw/send-back/archive are audited.
Staff roles: pharmacists prepare/reject prescriptions and create/edit doctors, medicines and tests (PHARMACIST only); admins read them. Admin dashboard, analytics, routines panel and AI suggestions are ADMIN only; pharmacists have GET /pharmacist/dashboard. Health rules and notice drafts stay open to both. The panel's role layouts read the role from GET /users/me; the backend guards are the real check.
Catalog: a medicine typed on a line without a catalog pick becomes a stub Medicine (brand name only, matched case-insensitively) for a pharmacist to complete; a typed doctor creates a Doctor row (same BMDC number = same doctor); "Not applicable" creates none. Completeness (catalog/lib/catalog-completeness.ts, one rule for filters, the `incomplete` flag and both dashboards): a doctor needs name, specialty, phone and chamber (the free-text address; BMDC number and district optional); a medicine needs brand name, form, category and manufacturer (generic name optional). createdById on doctors/medicines is overwritten by every pharmacist edit ("Created by" = last pharmacist to save; the original creator stays in AuditLog); createdBy and patient counts are in ADMIN responses only (a patient's self-added stub would show their name). Autosuggest is prefix search via lower(col) LIKE 'x%' on the text_pattern_ops indexes in pending SQL 004 (not in schema.prisma).
Prescription statuses: PENDING -> REJECTED or AWAITING_CONFIRMATION -> ACTIVE -> ENDED. Completing (pharmacist) sets AWAITING_CONFIRMATION and creates no routine; POST /prescriptions/:id/confirm (patient or caregiver) validates the allowed edits and calls PrescriptionsService.activate() (AWAITING_CONFIRMATION -> ACTIVE, routines + doses + health rules). Edits go into the routine (lastEditedById = who confirmed), the pharmacist's line stays as written; removed lines are deleted (audited). uploadedById/confirmedById record who acted; responses expose only uploadedByCaregiver/confirmedByCaregiver. A re-upload carries previousPrescriptionId (only to the uploader's own REJECTED prescription). Medicine lines carry a revision; prescriptions have currentRevision / pendingRevision for a pharmacist edit made after activation.
Rolling doses: routine generation creates doses only ROLLING_HORIZON_DAYS (14) ahead and stores scheduleTimes + generatedUntil on the routine; RollingDoseJob (hourly, ROLLING_DOSE_JOB_ENABLED) extends active routines with a compare-and-set on generatedUntil, batch after batch (keyset on generatedUntil, id) until all are done or a 10-minute budget, since every routine needs one extension a day. Continuous lines have no endDate. Routines from before Round 4 have no scheduleTimes and are left alone.
Address: users.divisionId/districtId/upazilaId with composite foreign keys (districts(id, divisionId), upazilas(id, districtId)) and CHECK constraints, so a level can't belong to another parent or skip the one above.
Privacy flag ("Hide from family", off by default) is users.profileVisibleToFamily stored inverted; hidden users are hidden from every family member, caregiver included, get no family missed-dose alerts, and can't be acted for.
Caregiver access: FamilyRole is CAREGIVER | MEMBER (OWNER renamed in pending SQL 005). User endpoints that accept `?forUserId=` (prescriptions upload/mine/:id/confirm; medicine-schedule routines CRUD, routines/:id). Marking a dose taken (POST doses/:id/taken) has no forUserId: a dose is only ever marked by its own patient resolve it through family/CaregiverAccessService: only the caregiver of the member's family, member visible, USER and ACTIVE; anything else is 404. Caregiver actions call notifyMember (SYSTEM notification, data.kind caregiver_action, neutral text). Who acted is stored as ids (prescriptions.uploadedById/confirmedById, medicine_routines.createdById/lastEditedById) and sent to apps only as labels (YOU | CAREGIVER, selfAdded). The app's offline queue is for the user's own actions only; caregiver screens are online.
Routines (RoutineManagementService): a pharmacist's routine accepts only scheduleTimes (same count) and mealTimingId; a self-added one (source SELF_ADDED) accepts all fields. A schedule change replaces future PENDING doses (past and taken ones stay); remove sets active=false and deletes future PENDING doses. Start/end/horizon logic is planSchedule() in routine-generation.service.ts, shared with prescription routines. The app's dose cache drops synced doses the server no longer returns, so changed/removed medicines stop reminding.
AuditLog: append-only (actor, subject user, action, entity, before/after JSON) via AuditService.record (pass the transaction client); never store secrets, phone numbers or rejection text in it. Written today: prescription.prepare/reject/confirm, doctor.create/update, medicine.create/update, routine.create/update/remove.
Pagination: common/utils/cursor-pagination.ts (keyset on createdAt DESC, id DESC; ADMIN_PAGE_SIZE 20, USER_PAGE_SIZE 10). Ranked analytics lists (ordered by a count) page by offset, sent as the same opaque `cursor` so the panel's Pager works unchanged.
Admin analytics (AdminAnalyticsService, GET /admin/analytics, /divisions/:id, /top-doctors, /top-medicines; ADMIN only): live queries behind a 5-minute in-memory TtlCache (single instance; responses carry generatedAt and cacheSeconds), no rollup tables (Q2 decision; revisit after the Round 9 query audit). Users = role USER, not DELETED; missing details count as "Not set"; age bands 0-17/18-39/40-59/60+ on the app-timezone date. Patients of a doctor/medicine (catalog/lib/patient-counts.ts) = distinct patients on ACTIVE/ENDED prescriptions, medicine lines of the current revision only; self-added routines aren't counted (no medicine id).
Medicine reminder groups (NotificationScheduler): doses due at the same time share one group; ScheduledMedicineNotifications rows are keyed `grp:<T ms>:<hash of dose ids>` (group), `snz:<group key>` (pending Later: notificationId = stage, scheduledAt = ring time) and `health:<id>`, so the Drift schema did not change. Stage 0 at T, stage 1 at T+30 or after the first Later, stage 2 only after a second Later (no Later button). Ringing uses channel `medicine_alarm` (alarm tone, FLAG_INSISTENT, timeoutAfter 2 min) and a silent copy on `medicine_reminders` at +2 min. Payload JSON {type: MEDICINE_REMINDER, at, stage}.
Background work (notifications/reminder_actions.dart): Done/Later and the FCM backstop run in a background isolate when the app is closed, through a ProviderContainer opened by openBackgroundContainer(); main() owns the app's ProviderContainer (UncontrolledProviderScope) so foreground actions use the same services. AppDatabase opens with shareAcrossIsolates. Done tries to sync immediately.
Reminder switch: the account owns medicineRemindersEnabled; SessionServices mirrors it into SharedPreferences (ReminderPreference) so the scheduler obeys it offline and in background isolates.
Backstop push: MissedDoseAlertService.sendBackstops creates one MEDICINE_REMINDER notification per (user, scheduled time) with untaken doses at +30 min (patient only, reminders on), relatedEntityId `backstop:<iso>`, sent data-only; it selects whole groups that have no backstop yet (raw SQL, NOT EXISTS on that key) batch after batch, so every patient at the busiest minute gets one with all of the group's dose ids. Family alerts are also taken batch after batch (keyset on scheduledAt, id), each job run stopping after a 45-second budget; the app shows it as the group's stage-1 reminder (same id, replaces the local repeat) or drops it when its local cache shows the doses taken. Push rules: NOTICE needs noticesEnabled, MEDICINE_REMINDER needs medicineRemindersEnabled, everything needs notificationsEnabled.
Missed-dose grace default is 62 minutes (DOSE_MISSED_GRACE_MINUTES); family alerts also require the patient's medicineRemindersEnabled.
6. Coding conventions

Match the surrounding file. Observed in the code:

Backend: Nest file naming kebab-case.type.ts (*.module|controller|service|dto.ts); PascalCase classes, camelCase members. Global ValidationPipe with whitelist, forbidNonWhitelisted, transform: every request body needs a DTO with class-validator decorators, and unknown fields are rejected. Global prefix api. Errors use Nest HTTP exceptions, formatted by common/filters/http-exception.filter.ts. Prisma only through PrismaService. Config via @nestjs/config / .env.
Backend tests: colocated __tests__/ or *.spec.ts beside the file; DB-backed ones use makeTestPrisma() and skip without TEST_DATABASE_URL.
Admin: App Router, one page.tsx per route, shared pieces in components/, all HTTP through lib/api-client.ts. Each area's layout gates by role (useRequireRole) and renders AppShell; pages render <Topbar title> as their heading. Admin links use ADMIN_BASE from lib/paths.ts. Plain CSS in app/globals.css (no UI library). Colors only through the :root tokens (--color-*), which have dark values under prefers-color-scheme and :root[data-theme='dark']; no literal colors in CSS or components. lib/theme.ts holds the choice and the boot script in the root layout's <head>.
Mobile theme: AppTheme.light()/dark() share one builder; text and status colors come from AppPalette (`context.palette.muted/subtle/success/warning/info/...`), never fixed Colors.grey/green/orange shades. The theme mode is ThemeModeController (PrefsKeys.themeMode).
Mobile: user lists use widgets/load_more_list.dart (10 rows + "Load more"; the inbox pages on the server, 10 per page). Dropdown options come from core/lookups (GET /lookups, public). "by caregiver" etc. use widgets/caregiver_tag.dart (TagChip). Mobile: feature-first data/domain/presentation layers; Riverpod providers (providers/core_providers.dart), go_router (router/app_router.dart), Dio for HTTP, Drift for local data. UI strings live in core/localization/app_strings.dart; add both English and Bengali for every string.
Database: during development change only backend/prisma/schema.prisma (no new migration files) and add the matching SQL as the next numbered file in backend/prisma/pending-sql/ (listed under "Database changes (pending SQL for Neon)" in plan.md); the owner runs them in the Neon SQL editor at the end of development. Generate the SQL with `prisma migrate diff --from-schema-datamodel <previous schema> --to-schema-datamodel prisma/schema.prisma --script`, then hand-fix data conversions (enum value changes) and add what Prisma can't express (CHECK constraints). Verify on a disposable Postgres (all migrations + pending files, then diff against the schema). Never edit an existing applied migration.
Dropdowns: every dropdown reads a lookup table (genders, divisions, districts, upazilas, doctor_specialties, medicine_forms, medicine_categories, meal_timings, test_categories), English only, edited by the owner in the database. No hard-coded option lists.
Medical privacy: never log prescriptions, readings, phone numbers, tokens, or passwords. Passwords use Argon2. Notifications that name medicines or readings need a neutral public (lock-screen) version; details appear only after unlock (shared phones are common).
AI safety: never bypass the safety filter, auto-publish AI output, or add diagnosis/prescribing behavior.
Secrets: .env only; keep .env.example current; never commit real keys.
7. Environment variables (backend/.env.example)

DATABASE_URL, PORT, CORS_ORIGINS, CLOUDINARY_CLOUD_NAME|API_KEY|API_SECRET, LLM_API_BASE_URL|LLM_API_KEY|LLM_MODEL, JWT_ACCESS_SECRET (required, app won't start without it), JWT_ACCESS_EXPIRES_IN, PUSH_TOKEN_ENC_KEY (required, openssl rand -base64 32), one of FIREBASE_SERVICE_ACCOUNT_BASE64|JSON / GOOGLE_APPLICATION_CREDENTIALS (without one, push is disabled), APP_UTC_OFFSET_MINUTES, DOSE_MISSED_GRACE_MINUTES (default 62; a deployed value overrides it), MISSED_ALERT_MAX_AGE_MINUTES, MISSED_DOSE_JOB_ENABLED, ROLLING_DOSE_JOB_ENABLED, PUSH_DISPATCH_JOB_ENABLED, NOTICE_SCHEDULE_JOB_ENABLED, TRUST_PROXY, RATE_LIMIT_ENABLED|RATE_LIMIT_USER_PER_MINUTE (120)|RATE_LIMIT_IP_PER_MINUTE (60), SMS_API_URL|SMS_API_KEY|SMS_SENDER_ID, SEED_ADMIN_PHONE|SEED_ADMIN_PASSWORD, SEED_PHARMACIST_PHONE|SEED_PHARMACIST_PASSWORD (seed only). Admin: NEXT_PUBLIC_API_BASE_URL.

8. Rules and don'ts
Never break existing things without asking first (API contracts, DB schema, Drift schema, existing behavior).
Don't add dependencies without asking. Name the package, why, and alternatives.
Always add tests for bug fixes (fails before the fix, passes after).
Don't assume anything. If confused, ask me.
Keep current architecture and conventions; keep changes small and scoped; no drive-by refactors.
Don't run destructive DB commands (migrate reset, drops, TRUNCATE-based tests) against anything but a disposable DB.
Don't run more than one API instance.
9. Known issues / open questions (do not fix without asking)
Mobile has a diabetes feature folder with only presentation/, not listed in the README.
Admin has no tests. Mobile tests cover the reminder scheduler, sync queue, inbox tabs, the re-upload link and the dose-cache cleanup, not widgets or background isolates.
DB-backed integration specs that register users need the lookup tables (pending SQL 003) or create minimal rows themselves (test-utils signupDetails).
flutter_local_notifications 19.5 has no notification public version, so medicine reminders always use neutral text (count + time) instead of names-after-unlock.
mobile/.gitignore: the Xcode rules `profile` and `**/*sync/` are scoped to ios/ (unscoped, they hid lib/features/profile/, lib/sync/ and android/app/src/profile/ from git). Keep new Xcode-template rules under ios/.
All backend specs pass, DB-backed ones included (Round 9); integration specs use the real /api prefix.
Stray tsc output (*.js/*.d.ts next to sources, backend/jest.config.js) is gitignored; if it reappears, delete it: a second jest config breaks `npm test`.
Release build is signed with the debug key (android/app/build.gradle.kts); needs a real upload key before Play Store (docs/release/android-release-notes.md).
10. Current work

Tracked in @PLAN.md.

11. Maintenance rule

With every development phase: update CLAUDE.md (existing work: features, commands, structure, conventions) and PLAN.md (future work) before calling the phase done.