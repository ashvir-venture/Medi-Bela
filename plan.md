Locked decisions
Platform: Android first. iOS gets a loud best-effort notification.
Caregiver: the family OWNER. Members must have accounts. The privacy flag defaults to off and hides a user from other members only, and the invitation shows a warning.
Routine flow: upload → pharmacist prepares or rejects with feedback → user or caregiver chooses Confirm or Edit → reminders start. After that only Edit exists. User edits apply directly, and a pharmacist edit after activation arrives as a Confirm or Edit prompt while the old version keeps running.
Doctor and medicine data: pharmacists complete them, and admin is read-only. Strength lives on the routine line, not in the Medicine table. Doctor to medicine runs through Prescription → PrescriptionMedicine.
Performance: pagination is 20 rows per page for admin (Next and Previous) and 10 for users (“Load more”). Indexes are write-light, analytics use rollups (Q2), and there is a query audit (Q3).
Rate limiting: a global limit now. The AI cap already exists. The limits on SMS, upload and search are yours later.
Rate limit design (to be built in Round 2)
Limits: one global limit on every endpoint, counted per user id when signed in and per client IP on public routes. Per-IP would punish many users who share a mobile-carrier IP. Defaults are 120 requests per minute per user and 60 per minute per IP on public routes, adjustable from environment settings.
Placement: the limiter runs after the JWT guard, skips /health, and is off under tests. It returns 429 with a Retry-After header.
Deploy requirement: set TRUST_PROXY=1 if the API sits behind a proxy. If you don’t, all public traffic shares a single bucket.
Mobile risk I found: the sync queue gives up after 5 failures and reverts the local “taken” state, and it polls every 30 seconds. Without a fix, a 429 could silently lose dose-taken events. The fix treats 429 as “pause and retry later”, not as a failure.
Limits: the counter lives in memory, so it works for a single server only. Redis comes later if you add instances. Bad-token requests that return 401 aren’t counted, so a host-level limit would cover them.
Testing: device testing (the three-phone matrix in Round 1 and the Round 3 behaviors) is deferred until all rounds are developed; each round is "code done" until then.

Database changes (pending SQL for Neon)
Workflow: during development only backend/prisma/schema.prisma changes (no migration files). The matching SQL goes into ordered files in backend/prisma/pending-sql/. At the end of development, run them in the Neon SQL editor in order, then `npx prisma generate`. Each file was checked on a disposable Postgres replaying every existing migration, with the result diffed against schema.prisma (no differences).
1. 001_round3_reminder_and_notice_toggles.sql - reminder and notice switches.
2. 002_round4_schema.sql - Round 4 tables and columns. Converts existing COMPLETED prescriptions to ACTIVE in the same step.
3. 003_round4_reference_data.sql - dropdown data (divisions/districts/upazilas from github.com/nuhil/bangladesh-geocode, genders, doctor specialties, medicine forms and categories, meal timings, test categories). Safe to re-run.
4. 004_round5_search_indexes.sql - prefix-search indexes for doctor / medicine / test autosuggest (expression indexes, not in schema.prisma). Safe to re-run.
5. 005_round6_caregiver.sql - family role OWNER renamed to CAREGIVER (in place, existing rows convert), and who-acted columns (prescriptions.uploadedById/confirmedById/confirmedAt, medicine_routines.createdById).
6. 006_round7_notice_review_note.sql - notices.reviewNote (admin's note when sending a notice back).
Until these run, the deployed API's queries on the new columns fail, so don't deploy Round 3+ backend code before the SQL is applied.

Rounds
Round 1: Reminder delivery (top priority) - CODE DONE 2026-10-28, device testing pending
Done in code: POST_NOTIFICATIONS / RECEIVE_BOOT_COMPLETED / SCHEDULE_EXACT_ALARM, plugin boot + scheduled receivers, exact alarms when allowed with inexactAllowWhileIdle fallback, re-register all reminders once per process and on permission change, res/raw/keep.xml for the notification icon (Gson keep rules ship with the plugin since v19), Reminder check screen (notifications, alarms & reminders, battery optimization, vendor Autostart tip; EN + BN), banner on Home and Today's medicine, scheduler unit tests.
Still open: run the device matrix below; exactAllowWhileIdle is limited to roughly one alarm per 9 minutes per app in Doze, so several medicines at the same time can arrive late until Round 3 groups them (or switch to alarmClock mode); release build still signed with the debug key.
Test phones: (1) budget Redmi, HyperOS/MIUI, Android 14-15; (2) Samsung Galaxy A-series, One UI, Android 14-15 (exact alarm denied by default); (3) about 4 GB realme / vivo / OPPO, Android 12-13. Emulators and Pixels don't count. Swap #3 for Infinix / Tecno / itel if users skew very low-budget. Confirm Flutter's default minSdk.
Pass when a reminder fires within 2 minutes when exact alarms are granted, and within 10-15 minutes when they are denied and the inexact fallback is used (starting targets, not measured values), on all three phones in each case: app swiped away; screen off 30+ minutes; overnight; after reboot; exact alarm granted and again denied; notification permission denied (app shows a clear warning); phone offline.
Test a release build on a real phone, then fix the cause: permissions, exact alarms, alarm-sound channel, R8/ProGuard rules and reboot reschedule.
Add a “Reminders status” check with a warning banner on the Today screen.
Done when: reminders fire on time with the app closed, survive a reboot, and work on all 3 test phones.
Round 2: Global rate limit and quick hardening - DONE 2026-10-28
Done: @nestjs/throttler global guard (RATE_LIMIT_* env), mobile sync queue pauses on 429, new prescription images private with 1-hour signed links (old public test images stay public; delete them by hand), notice publish is ADMIN only, stray compiled .js/.d.ts deleted (already gitignored). Tests: rate-limit.spec, prescription-image-url.spec, notices-roles.spec, mobile sync_service_test.
Follow-ups: the admin panel still shows Publish to pharmacists (backend now returns 403; Round 7 adds role-aware UI); pharmacists can still PATCH an already-published notice's text.
The limiter above, plus the mobile 429 fix and a test for both.
Private Cloudinary images with signed URLs.
Pharmacists can no longer publish notices.
Remove compiled .js and .d.ts files from the repo.
Done when: the limiter returns 429 correctly, the mobile queue survives throttling, and existing specs still pass.
Round 3: Reminder behavior - CODE DONE 2026-10-29, device testing pending
One grouped reminder per time. Done and Later buttons work outside the app, and Later snoozes 30 minutes, twice at most.
Alarm for about 2 minutes, then a repeat at 30 minutes.
The family alert fires only after the second reminder goes unanswered, with the server missed timing cut from 120 to about 32 minutes. A backstop push goes out at the second-reminder time.
Separate notice and reminder toggles, an alarm sound for reminders, and a Personal tab.
Done when: every behavior in your plan works on the test phones.
Built: grouped alarm-style reminders (ring 2 min, silent copy, repeat +30), Done/Later with the app closed (Later 30 min, max twice; snoozes survive restarts), neutral lock-screen text, medicine-reminders and notices switches (users.medicineRemindersEnabled / noticesEnabled; SQL in "Database changes" above), notice push respects its switch (moved here from Round 7), backstop push at +30 (data-only, dropped by the app if taken locally), family alert at +62 and none when reminders are off, inbox tabs Personal / Family / General.
Not as decided / still open:
- Lock screen: the notification plugin (19.5) has no public version, so reminders always show neutral text ("2 medicines are due at 8:00 AM") and names only in the app, never after unlock. A native public version would need a plugin patch or fork.
- Full-screen alert vs distinct-sound channel: only the distinct-sound channel (medicine_alarm) is built; compare on the test phones before deciding on USE_FULL_SCREEN_INTENT.
- In Doze, exact alarms are limited to about one per 9 minutes per app, so the silent copy at +2 can arrive later (the ring itself is still removed at 2 minutes).
- Inbox tabs filter the pages loaded so far (server has no per-tab filter); a tab can look empty until "Load more".
- Check production .env for DOSE_MISSED_GRACE_MINUTES before release; a set value overrides the new 62 default.
- iOS: no Done/Later buttons (needs notification categories) and no silent copy; best effort as planned.
Decisions (2026-10-29):
- Sound: compare full-screen alerts (USE_FULL_SCREEN_INTENT, Play review risk) against a high-importance channel with its own distinct sound (no review risk). Ship the distinct-sound channel as the baseline. Reminders respect silent/vibrate. Use the phone's default alarm tone. Sound repeats until touched and is silenced after about 2 minutes.
- Family alert: sent at 60 minutes, after the last allowed reminder (2 Laters x 30 min), so never while a snooze is still running.
- Backstop push at the second-reminder time (30 min): patient only. The server can't know about a dose marked taken offline and not yet synced, so the app drops the push if its local database already shows the dose as taken.
- Server missed timing: change only the default of DOSE_MISSED_GRACE_MINUTES; it stays configurable and the server decides. A value already set in the deployed .env overrides the new default, so check production before release.
- [ASK] The plan said about 32 minutes, but a 60-minute family alert needs the dose to stay open until then. Proposed default: about 62 minutes (60 + 2-minute ring). Confirm before building.
- Lock screen: neutral text ("Time for your medicine") as the public version; medicine names only in the private version shown after unlock. Many phones in Bangladesh are shared.
- Grouping: one notification per scheduled time. Done marks every dose in the group taken; taking only some is done in the app.
- Health reminders (e.g. check sugar) stay normal notifications.
- Reminder toggle: if a user turns medicine reminders off, there are no reminders and no family missed-dose alerts either. The switch shows a warning.
- Inbox tabs: Personal updates (own doses, prescription updates), Family (family members' alerts and info), General (notices; Round 7 adds scheduling and division filtering).
Round 4: Data foundation - CODE DONE 2026-10-29
User fields and geo tables, then Doctor, Medicine, DiagnosticTest and the doctor-genre list.
New prescription statuses and structured medicine lines, routine columns and AuditLog.
Notice fields and the privacy flag.
Rolling dose generation, the cursor pagination helper, and the write-light indexes.
Migrate existing prescriptions and routines to active, so no reminders stop.
Done when: migrations pass on a copy of real data and the specs are green.
Decisions (2026-10-29): English only for lookup data; every dropdown reads a database table the owner edits (genders, divisions, districts, upazilas, doctor specialties, medicine forms, medicine categories, meal timings, test categories); address levels are enforced in the database (composite foreign keys plus CHECK constraints: a district must be in the chosen division, an upazila in the chosen district); the privacy flag is "Hide from family", off by default, and hides the user from everyone in the family including the owner (stored as users.profileVisibleToFamily, inverted).
Built: user fields (dateOfBirth, gender, division/district/upazila), lookup tables, Doctor (BMDC number unique), Medicine (strength stays on lines), DiagnosticTest + prescription tests, prescription statuses PENDING / REJECTED / AWAITING_CONFIRMATION / ACTIVE / ENDED, prescription fields (doctor, visit date, diagnosis, next visit, re-upload link, current/pending revision), structured lines (medicine, strength, dose amount, meal timing, continuous, revision), routine columns (source, strength, dose amount, meal timing, schedule times, generatedUntil, last edited by), notice fields (source, source link, startsAt, approval, divisions, PENDING_APPROVAL), AuditLog, rolling dose generation (14 days ahead, hourly RollingDoseJob, ROLLING_DOSE_JOB_ENABLED), cursor pagination helper (20 admin / 10 user), prescriptions index (status, createdAt). Completing a prescription now sets ACTIVE (Round 6 switches it to AWAITING_CONFIRMATION). The app shows the Hide from family switch and the new status labels; the admin panel shows the new statuses.
Not done / open:
- Tested on a disposable database with fixture data, not a copy of the real Neon data. Make a Neon branch, run the three files there first.
- AuditLog: pharmacist actions are written since Round 5; caregiver actions arrive in Round 6.
- Cursor helper: the Round 5 prescription queue and doctor/medicine lists use it; the remaining screens switch over in Rounds 6-8.
- Autosuggest indexes: done in Round 5 (prefix search, pending SQL 004).
- Stale integration tests (fail with or without Round 4): mvp-flow.int.spec expects no public routes besides register/login (health, forgot-password and reset-password are public) and rejects 7-character passwords; admin.int.spec calls an assistant endpoint that now returns 404.
Round 5: Pharmacist portal - CODE DONE 2026-10-29
The prescription form from your plan: doctor block, medicine form, diagnosis form, next visit date, and “Add new” collapsing the previous entry to one line.
Autosuggest for medicines and tests, and a portal where pharmacists complete doctor and medicine records.
Reject with feedback and a linked re-upload, then send for confirmation. Queues are paginated at 20.
Done when: a prescription goes from upload to AWAITING_CONFIRMATION and doctor-to-medicine rows are correct.
Decisions (2026-10-29):
- Completing sets AWAITING_CONFIRMATION now, even before the Round 6 Confirm screen exists: new prescriptions get no reminders until Round 6 ships.
- Pharmacists use the panel's root URLs; the admin area is a fixed unlisted path, /super-control-007. Both get a dashboard with their own overview and a left sidebar; responsive; own components, no UI library.
- Round 5 builds the admin shell only (sidebar, gate, existing pages moved); admin content (doctor/medicine data view, user analytics, notice approval) stays in Round 7.
- Autosuggest: prefix search (no pg_trgm).
- Doctor block: name required; "Not applicable" option. A typed name creates a Doctor row; Not applicable creates none.
- Reject: backend + app Re-upload button in this round.
Built: GET /prescriptions/admin/queue (status filter, 20 per page), PUT /prescriptions/admin/:id/details (doctor pick / new doctor / Not applicable, visit date, diagnosis, next visit, tests), structured medicine lines linked to the catalog (typed names become stub Medicines), complete -> AWAITING_CONFIRMATION with a "ready to confirm" notification, PrescriptionsService.activate() for Round 6 (routines, doses, health rules, "active" notification), re-upload link (previousPrescriptionId, own REJECTED only), /catalog (doctor/medicine/test search, lists with "incomplete" filter, create/edit), /lookups (dropdown tables), GET /pharmacist/dashboard, AuditLog rows for pharmacist actions, optional seed pharmacist. Roles: prescription and catalog writes are PHARMACIST only (admin read-only); admin dashboard, routines panel and AI suggestions are ADMIN only. Panel: sidebar shell, role gates via /users/me, pharmacist dashboard, queue, prescription workspace (photo beside the form), doctors and medicines pages, admin area under /super-control-007, notice pages shared by both (Publish only for admin). App: Re-upload button and hint on a rejected prescription (EN + BN), link sent through the existing outbox payload (no Drift change). Also restored the panel's list pages (prescriptions, routines, notices, health rules, AI suggestions), which commit a667029 had overwritten with copies of the detail pages, and stopped the login page logging the access token to the console.
Checked: backend unit + integration specs (disposable Postgres), pending SQL 001-004 replayed and diffed (no differences), mobile tests + analyze, panel build, and a browser run of login, queue, form, send, reject, phone layout and role redirects against a disposable database.
Not done / open:
- No Confirm screen yet (Round 6): prescriptions prepared now wait in AWAITING_CONFIRMATION; nothing calls activate().
- The app still labels AWAITING_CONFIRMATION "Awaiting confirmation" with no action; the "ready to confirm" push tells users to open the app.
- Admin panel's "Completed prescriptions" count on the admin dashboard does not include AWAITING_CONFIRMATION (Round 7 reworks admin analytics).
- Clearing an already-set doctor field (e.g. a wrong BMDC number) isn't possible from the doctor page; only filling in. Doctors/medicines can't be merged when duplicates appear.
- Health rules stay editable by pharmacists (backend allows both roles); only pharmacists see the page.
- Admin `next lint` still has no ESLint setup (see CLAUDE.md [ASK]).
Round 6: User app - CODE DONE 2026-10-29, device testing pending
The Confirm or Edit screen. Routines and doses are created at confirm.
Manual routine create, edit and remove, with “self-added” and “edited by you” labels.
Caregiver actions with audit entries, the invitation warning, the privacy flag, and the new registration fields.
Larger buttons and basic colors, and 10-row “Load more” lists.
Done when: a user and a caregiver can complete the whole flow end to end.
Decisions (2026-10-29):
- Confirm or Edit allows dose times (same count), start date, meal timing and removing a medicine; dose amount, strength and duration stay as the pharmacist set them.
- The family "owner" is called caregiver everywhere, including the database and API (FamilyRole.CAREGIVER). The caregiver can confirm/edit prescriptions, manage routines and upload prescriptions for members; each item shows "by caregiver" and the member gets a push.
- Changed later the same day: the caregiver must NOT mark doses taken. Only the patient marks their own doses (Taken / Later); the caregiver only views them and gets missed-dose alerts like every family member. The dose "marked by" column (server and app cache) was removed again.
- Pharmacist edits of an already-active prescription (revisions) are deferred to a later round.
- Signup requires date of birth, gender, division, district and upazila (no existing users to migrate). Profile gets an "Edit your details" button that opens its own page.
- Self-added medicines use the catalog autosuggest plus free text (a new name becomes a stub for pharmacists).
- Look: app-wide theme only (larger text, 48dp+ targets, same green brand color); no per-screen redesign.
Built: POST /prescriptions/:id/confirm, caregiver access via ?forUserId= (CaregiverAccessService), routines create/edit/remove (RoutineManagementService), who-acted columns + labels, audit rows and neutral member pushes, required signup details with address-chain checks, public /lookups, medicine search open to patients. App: Confirm or Edit screen, "Review and confirm" on prepared prescriptions (also ones the caregiver uploaded), My medicines with labels, add/edit/remove form, caregiver tools on a member's page (medicines, prescriptions with upload; today's doses read-only), signup details, Edit your details page, invitation warning, "Caregiver" wording, caregiver pushes on the Family tab, theme, Load more on prescriptions, health records, notices and conversations (inbox 10 per page). Dose cache now drops doses the server removed (changed/stopped medicines stop ringing).
Checked: backend unit tests, all DB-backed specs incl. new caregiver-flow.int.spec on a disposable Postgres (only the known stale ones fail), pending SQL 001-005 replayed with an OWNER row and diffed (no differences), mobile tests (31) + analyze + release build.
Not done / open:
- Not run on a phone yet (device testing deferred): the new screens are checked by analyze and unit tests only.
- Caregiver screens need internet (the member's data isn't cached on the caregiver's phone).
- Pharmacist revisions of active prescriptions (pendingRevision prompt) are deferred.
- The admin panel doesn't show who uploaded/confirmed (Round 7 can add it).
- rolling-dose.int.spec failed once in a full run that stalled for 18 minutes and passed on every rerun; watch for flakiness.
Round 7: Notices and admin shell 
One login that redirects by role. Pharmacists go to the current dashboard and admins to different dashboard protected by unique url extension, with server-side checks.
Notice form with source display. A pharmacist drafts, an admin approves, and admin-created notices publish directly.
A start-date job, division filtering, and General-tab polish (the notice push switch and the General tab shipped in Round 3).
Done when: draft, approval, scheduled publish and the user’s tab all work.
Status: CODE DONE 2026-10-29, device testing pending. (Login redirect by role and the admin path were built in Round 5.)
Decisions (2026-10-29):
- An admin sends a pharmacist's notice back with a required note (new column, SQL 006); the pharmacist may withdraw a pending notice to draft. Pharmacists change only drafts.
- Source (name and https link) is optional; the app shows the source name only, no link.
- Divisions: one rule for the user's Notices list and the push: nationwide notices plus their own division's.
- General tab: source on notice cards, a notice push/inbox entry opens that notice (shown first, highlighted), and an "All notices" button.
Built: submit / withdraw / send-back endpoints, publish = approve (admin), scheduled publishing via NoticeScheduleJob (NOTICE_SCHEDULE_JOB_ENABLED), division filter on list and push, audit rows for notice actions, user notices carry the source; admin panel notice form (source, link, show-from, expiry, divisions) with role-based actions and a "Waiting for approval" tab; app changes above. Admin dashboard "live notices" no longer counts scheduled ones.
Checked: notice role spec + notices-flow.int.spec (approval, send-back, schedule once, divisions) on a disposable Postgres, SQL 006 diffed (no differences), mobile tests (33) + analyze, admin build.
Not done / open:
- Not run on a phone; admin pages not clicked through in a browser this round.
- A notice already published can't be re-targeted to divisions after its push went out (the push isn't repeated); edit before publishing.
Round 8: Admin analytics - CODE DONE 2026-10-29
Dashboard with users by area, age and gender, total families, doctors with the most patients, and most-used medicines.
The madeBy view, a count of incomplete doctor and medicine records, and read-only doctor and medicine lists.
Q2 rollups for speed.
Done when: every number loads fast and matches the source data.
Decisions (2026-10-29):
- Speed: live queries on indexed columns with a 5-minute in-memory cache on the admin analytics endpoint; no rollup table unless the Round 9 query audit shows it is slow.
- Users by area: per division, opening a division shows its districts. Age bands 0-17 / 18-39 / 40-59 / 60+. Role USER, not deleted; missing fields count as "Not set". Exact counts (no small-group hiding).
- Top doctors: distinct patients on ACTIVE + ENDED prescriptions, top 10, all time.
- Most-used medicines: distinct patients per catalog medicine on ACTIVE + ENDED prescription lines, top 10, all time (self-added routines not counted: they store no medicine id).
- madeBy: doctors and medicines show "Created by" (the pharmacist's name, or the patient's/caregiver's name for a stub they created) in the admin area only. No edit column: a pharmacist edit overwrites createdById with that pharmacist; the earlier creator stays in AuditLog. Pharmacists keep editing as today.
- Incomplete doctor: missing name, specialty, phone or chamber (chamber is the free-text address, relabelled "Chamber / address"); BMDC number and district are optional. Incomplete medicine: missing brand name, form, category or manufacturer (e.g. Seclo - Tablet - Gastric - Square Pharma); generic name is optional. Applies to the pharmacist dashboard count, the "Only incomplete" filter and the badges too.
- Admin doctor and medicine pages: sidebar links, 20-row lists (search, "Only incomplete", Created by), read-only detail page with patient count.
Built: GET /admin/analytics (users by division / gender / age with "Not set", people in families, catalog totals and incomplete counts, top 10 doctors and medicines), /admin/analytics/divisions/:id (districts), /top-doctors and /top-medicines (full rankings, 20 per page); all behind a 5-minute in-memory cache (TtlCache). One completeness rule (catalog-completeness.ts) used by the catalog filter, a new `incomplete` flag on each record and both dashboards. Pharmacist edits overwrite createdById. Admin catalog responses add createdBy (and patients on detail); pharmacist responses don't. No schema change, no pending SQL. Panel: analytics section on the admin dashboard (division bars open their districts), ranked pages, admin Doctors / Medicines lists and read-only record pages, pharmacist labels for the new rule ("Chamber / address").
Checked: backend unit tests (only the 2 known failures), all DB-backed specs (only the known stale ones fail). Fixed a clock-dependent test: mvp-flow's "complete journey" failed whenever the routine's real 08:00 / 20:00 dose was inside the missed-alert window (e.g. run at 22:30), giving a second, correct family alert; the test now moves the patient's other untaken doses a month ahead before running the job. No product code changed. Your local backend/.env still sets DOSE_MISSED_GRACE_MINUTES=120 (overrides the 62 default). on a disposable Postgres incl. new admin-analytics.int.spec (numbers vs. the tables, ranking rules, incomplete rule, Created by admin-only), panel build, and a browser run of the dashboard, district drill-down, ranked page, admin lists and record page (desktop and phone width) with demo data; the numbers matched direct SQL.
Not done / open:
- Speed is checked only on small demo data; Round 9's query audit should time /admin/analytics on production-sized data (the user breakdowns scan the users table; the rankings group prescriptions / lines).
- Numbers can be up to 5 minutes old; the dashboard's own Refresh button doesn't clear the analytics cache.
- Existing doctor/medicine records counted as complete under the old rule may now show as incomplete (and the other way round) until pharmacists fill phone, chamber and manufacturer.
Between Rounds 8 and 9 (2026-10-29): dark mode and sign-in language switcher - CODE DONE, device testing pending
Built: app dark theme (follows the phone; Profile → Appearance: System / Light / Dark, saved on the device), mode-aware text and status colors (AppPalette; light values unchanged), English | বাংলা switcher on login, register, forgot and reset password (synced to the account after sign-in like Profile). Panel dark mode via CSS tokens (follows the computer; System / Light / Dark in the sidebar footer and on the login page, remembered per browser, applied before paint), logo on a light plate in dark mode.
Checked: mobile tests (37, incl. theme and switcher tests) + analyze (no errors or warnings) + release build; panel build and a browser run in dark and light (login, dashboard, analytics, prescriptions, workspace).
Not done / open: the app's dark mode hasn't been seen on a phone (device testing deferred); the reminder notifications and lock-screen text keep the system's look.
Round 9: Hardening and release
The Q3 query audit, and dropping unused indexes after checking pg_stat_user_indexes.
Load test the dose and missed-dose jobs.
A backup and restore check, a staged rollout, and the Play Store exact-alarm policy check.
Decisions (2026-10-29):
- Deployment: Render hosts a pre-Round-1 version; the owner changes the env and redeploys after Round 9. Neon starts fresh (no users, old test data has no value): an empty database gets all migrations plus pending SQL 001-006 in order, then the seed (admin, optional pharmacist). Round 9 writes this cut-over as a backend runbook (new Neon DB, SQL, seed, Render env incl. DOSE_MISSED_GRACE_MINUTES, deploy, smoke test, rollback) and adds a step to delete the old public prescription test images in the Cloudinary console by hand. No Play Console plan.
- Index audit: a disposable DB loaded with synthetic data now (EXPLAIN the hot queries, propose drops); drops are confirmed later from pg_stat_user_indexes on Neon after real use.
- Load test: target 1,000 patients, but the design and the script must scale to 10,000-20,000 (size is a parameter). Fake data generated with SQL, the real jobs (rolling doses, missed-dose and backstop, notice schedule) and the hot reads timed by a ts-node script. No new dependency.
- Backup: a Neon restore runbook (point-in-time branch, or pg_dump / pg_restore) plus a local dump-and-restore rehearsal on the disposable Postgres; the owner runs the Neon part.
- Exact alarms: keep SCHEDULE_EXACT_ALARM with the inexact fallback (no USE_EXACT_ALARM). No Play upload for now, so the upload key (release signing) stays deferred; Play rejects debug-signed bundles, so it's needed before the first upload.
- Clean-up in this round: update the stale tests, settle the API prefix on /api (specs follow main.ts), remove the stray files after checking nothing reads them, and set every part to version 0.1.0 (mobile 0.1.0+1). Admin lint stays a later decision.
Status: CODE DONE 2026-10-30, device testing pending.
Built: docs/release/ (deploy-runbook for the fresh Neon + Render cut-over incl. migrations_phase4a/phase4a_extra.sql, which is in neither the migrations nor pending SQL; backup-restore; load-test-and-index-audit; android-release-notes with the exact-alarm declaration and the signing steps), backend/scripts/load-test.ts (size is --patients). Clean-up: stray files removed (none was referenced; body.json held a test password), versions 0.1.0, integration specs on /api, stale tests updated to current behavior (health service name, AI token cap 2000, public-route list incl. password reset and lookups, 6-character password minimum, assistant tests on the conversations API).
Checked: all 37 backend suites / 329 tests pass incl. DB-backed ones; the runbook sequence replayed on an empty Postgres (seed ok, no diff against schema.prisma); dump/restore of a 20,000-patient database (4.16M rows) identical; load test at 1,000 / 10,000 / 20,000 patients.
Found by the load test and fixed (2026-10-30, with tests that failed before):
- Backstop pushes reached only the first 200 doses in a window (151 of 1,000 patients at the 08:00 peak; 200 of 20,000). Now whole groups without a backstop are selected batch after batch: 20,000 of 20,000 within 2 minutes.
- The rolling-dose job extended 200 routines an hour and fell behind above about 2,400 patients (routines would run out of doses). Now one hourly run covers all routines (40,000 in about 2 minutes); finished short courses no longer block the routines behind them.
- Family alerts at the peak went out up to 30 minutes late at 20,000 patients; now within about 3 minutes.
- Each job run has a time budget (rolling 10 min, missed-dose 45 s); the next run continues.
- A notice to everyone creates one inbox row per user inside the every-minute job (21-110 s at 20,000 users); fine for now, batch it past ~50,000 users.
Index audit: no drops now; doctors_name_idx and medicines_genericName_idx are drop candidates once Neon's pg_stat_user_indexes confirms (query in the audit doc).
Fixed: the app's Change password dialog required 8 characters while its message, sign-up, reset and the server use 6; it now uses 6 (6 is final; change_password_dialog_test).
Not done: device testing (all rounds); upload key (deferred); Neon point-in-time restore must be tried in the Neon console after the deploy.

