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
Workflow: during development only backend/prisma/schema.prisma changes (no migration files). The matching SQL goes into ordered files in backend/prisma/pending-sql/. Since 2026-10-30 Claude applies each new file to the Neon DB in backend/.env itself: a read-only drift check first (`prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --script`), then `prisma db execute --file`, then the check again (must be empty); anything unexpected in the drift, or SQL that drops or converts data, is asked first. 001-008 are applied there. A new database still runs them in order (or fresh-install.sql), then `npx prisma generate`. Each file was checked on a disposable Postgres replaying every existing migration, with the result diffed against schema.prisma (no differences).
1. 001_round3_reminder_and_notice_toggles.sql - reminder and notice switches.
2. 002_round4_schema.sql - Round 4 tables and columns. Converts existing COMPLETED prescriptions to ACTIVE in the same step.
3. 003_round4_reference_data.sql - dropdown data (divisions/districts/upazilas from github.com/nuhil/bangladesh-geocode, genders, doctor specialties, medicine forms and categories, meal timings, test categories). Safe to re-run.
4. 004_round5_search_indexes.sql - prefix-search indexes for doctor / medicine / test autosuggest (expression indexes, not in schema.prisma). Safe to re-run.
5. 005_round6_caregiver.sql - family role OWNER renamed to CAREGIVER (in place, existing rows convert), and who-acted columns (prescriptions.uploadedById/confirmedById/confirmedAt, medicine_routines.createdById).
6. 006_round7_notice_review_note.sql - notices.reviewNote (admin's note when sending a notice back).
7. 007_generic_names.sql - medicine_generics table; medicines.genericName (text) becomes medicines.genericId, existing names copied over (one row per name ignoring case). One transaction.
8. 008_list_indexes.sql - (createdAt, id) indexes on medicine_routines and audit_logs for the pharmacist routine panel and the admin audit log. Index only, safe to re-run. APPLIED to the Neon DB in backend/.env on 2026-10-30 (owner's request); `prisma migrate diff --from-schema-datasource` showed no difference afterwards, i.e. 001-008 are all on that database.
9. 009_round10_account_lifecycle.sql - Round 10: DEACTIVATED status, nullable users.phone and prescriptions.imageUrl, users.deactivatedAt/deletedAt/suspendedAt/birthYear, family_events table. Additive only. APPLIED to the Neon DB in backend/.env on 2026-10-30 (drift check empty before and after); fresh-install.sql rebuilt.
10. 010_round11_terms_consent.sql - Round 11: users.termsAcceptedAt (when the user ticked the Privacy & terms box at sign-up). Additive. APPLIED to the Neon DB in backend/.env on 2026-10-31 (drift check empty before and after); fresh-install.sql rebuilt.
Fresh database: backend/prisma/fresh-install.sql is all migrations + phase4a_extra + every pending file in one script (with Prisma's _prisma_migrations rows), rebuilt by `bash scripts/build-fresh-install.sh` after each new pending file.
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
Index audit: no drops now; doctors_name_idx is a drop candidate (medicines_genericName_idx is gone with SQL 007) once Neon's pg_stat_user_indexes confirms (query in the audit doc).
Fixed: the app's Change password dialog required 8 characters while its message, sign-up, reset and the server use 6; it now uses 6 (6 is final; change_password_dialog_test).
Not done: device testing (all rounds); upload key (deferred); Neon point-in-time restore must be tried in the Neon console after the deploy.
After Round 9 (2026-10-30): generic names as a table - CODE DONE
Built: medicine_generics (pending SQL 007, unique ignoring case), medicines.genericId instead of free text. Pharmacists pick a generic from GET /catalog/generics/search (staff only) or type a new one (found ignoring case, else created); an empty name removes it. Responses keep the flat genericName (apps unchanged) and add generic {id, name}; PATCH/POST also take genericId. Medicine search still matches on the generic. Panel medicine page: Generic name uses the autosuggest. backend/prisma/fresh-install.sql (one script for an empty database) + scripts/build-fresh-install.sh.
Checked: SQL 007 on a copy of the old schema with sample rows (case/space variants merged, blanks left empty) and on a fresh database, both with no diff against schema.prisma; backend unit + DB-backed tests (generics.int.spec), lint, build; panel build.
Not done / open: no starter list of generics (pharmacists fill it; an import file if the owner supplies an official list). Prescription detail responses embed the medicine row, which now has genericId/generic instead of genericName (no app or panel code reads it). Clearing the Generic name box and saving now removes the generic (before, it was silently kept).
Fix (2026-10-30): seeded staff could not sign in
The seed stores SEED_ADMIN_PHONE / SEED_PHARMACIST_PHONE as written (e.g. 01810314801) but login normalized the typed number to +880..., so it never matched. Login and password reset now keep the phone as typed and match it exactly first, then normalized (app sign-ups still sign in with any spelling); throttle keys and the reset SMS use the normalized form. Sign-up and family invitations unchanged. Tests: seeded-phone-login.int.spec (failed before), phone-lookup.spec.
After Round 9 (2026-10-30): pharmacist AI suggestions, audit log, panel look - CODE DONE
Built: routines panel and AI suggestions moved from admin to pharmacist (/pharmacist/routines, /pharmacist/health-suggestions; old /admin paths removed; PHARMACIST only; 20 per page with search and filters; request/edit/publish/unpublish audited; pharmacist dashboard card "AI suggestions awaiting review", admin dashboard keeps the count without a link). Admin audit log (GET /admin/audit-logs with action / who / date filters, /filters, /:id with before/after) and its page. Pending SQL 008 (list indexes), applied to Neon. Panel: title "Medi-Bela Management", favicon from the logo mark, login redesigned (brand panel with the transparent logo and light medicine line art, roomy form, theme switch top-right), sidebar brand = logo mark + "Medi-Bela / Management" wordmark (no white plate), sun / moon / system theme switch with labels in every page header (moved out of the sidebar), no underlines on buttons or cards. Notices: a new notice has "Save draft" and "Submit for approval" (admin: "Publish"); pharmacist tabs "My drafts" / "Sent for approval".
Checked: backend lint, build, unit tests (audit-log.service.spec, health-suggestions.service.spec, staff-roles.spec); panel build; login page in light, dark and phone width.
Not done / open: admin.int.spec's new role checks need TEST_DATABASE_URL (not run here). The sidebar, audit log and moved pages were not looked at in a browser (needs a signed-in staff account). Some Argon2-heavy auth specs time out now and then when the full suite runs in parallel on this machine (they pass with --runInBand); unrelated to this change.
Round 10: Account lifecycle, family changes, panel redesign, app navigation - CODE DONE 2026-10-30, device testing pending
Scope, in build order: A database, B account lifecycle (deactivate / delete / ban), C family (leave, remove, caregiver handover, activity feed), D admin users page and prescriptions clean-up, E panel redesign (sign-in page and internal look), F app navigation, Profile and Settings, G checks and docs. Each part ends with lint, tests and build for what it touched; CLAUDE.md and plan.md are updated at the end of the round.

A. Database: pending SQL 009_round10_account_lifecycle.sql (schema.prisma first, SQL from `prisma migrate diff`, then fresh-install.sql rebuilt; applied to the Neon DB in backend/.env after the drift check, then the check again must show no difference)
- AccountStatus gains DEACTIVATED (ACTIVE | DEACTIVATED | SUSPENDED | DELETED). SUSPENDED is the admin ban.
- users.phone becomes nullable (still @unique; Postgres allows many NULLs). Only DELETED rows have NULL. Every phone lookup already filters by value, so NULL rows never match a login, reset or invitation.
- users gains deactivatedAt, deletedAt, suspendedAt (timestamp, nullable) and birthYear (int, nullable; filled on delete from dateOfBirth so age-band analytics stay right after the exact date is erased).
- New table family_events: id, familyId (FK families, cascade), kind (enum FamilyEventKind: JOINED | LEFT | REMOVED | CAREGIVER_CHANGED | CREATED), subjectUserId (FK users, set null), actorUserId (FK users, set null), createdAt; index (familyId, createdAt, id). Names are not copied: the feed shows each user's current name, "Deleted user" for a deleted one.
- prescriptions.imageUrl becomes nullable (a deleted user's kept prescriptions lose their photo; the panel shows "Photo deleted").
- No data conversion needed (no rows use the new values yet).

B. Account lifecycle

B1. Deactivate (user, from Settings → Account actions)
- API: POST /users/me/deactivate {password}. Password checked with the same throttle as delete (403 on a wrong password, never 401). USER role only.
- Effect in one transaction: accountStatus = DEACTIVATED, deactivatedAt = now, passwordChangedAt = now (every existing token stops working on its next request; jwt-access.strategy already rejects non-ACTIVE). Audit user.deactivate.
- Before the device tokens stop being used: a data-only push {kind: "session_ended"} to every device of the user (PushService, not stored as an inbox notification). The app on receiving it (foreground or background isolate) cancels all scheduled reminders, clears the Drift database and secure storage, and shows Login on next open. Tokens are then deleted.
- The app syncs its queue before calling (all of these actions require being online; the button is disabled offline).
- While DEACTIVATED (every existing ACTIVE check already covers most of this; verify each):
  - no reminders, backstop pushes, pushed notices or any other push (notifications.service: non-ACTIVE never pushed);
  - missed-dose job: doses of non-ACTIVE users get no family alert (already); RollingDoseJob skips routines of non-ACTIVE users so no new doses are created (new filter); doses already created in the future are deleted at deactivation (PENDING only, scheduledAt > now), so the history doesn't fill with missed doses;
  - family: GET /family/members and member status return the member with status "paused" and no medicine data; the app shows "Account paused"; caregiver actions for them return 404 (CaregiverAccessService already requires ACTIVE);
  - a deactivated caregiver stays caregiver; their own caregiver screens are unreachable because they can't sign in.
- Reactivation: login with the right password on a DEACTIVATED account sets ACTIVE, deactivatedAt = null, audit user.reactivate, and the login response carries reactivated: true; the app shows "Welcome back" once. A successful SMS password reset on a DEACTIVATED account also reactivates (otherwise someone who forgot the password could never return). RollingDoseJob picks the routines up on its next run and continues from today (planSchedule already starts from max(start, today)). No expiry.

B2. Delete (user, from Settings → Account actions, two screens)
- Screen 1 (warning): what is erased and what is kept, "You can deactivate instead and come back later", buttons Deactivate instead / Continue to delete.
- Screen 2 (confirm): the user types the exact phrase, shown in the app's language:
  EN "I am sure about deletion and know the consequences"
  BN "আমি মুছে ফেলার বিষয়ে নিশ্চিত এবং পরিণতি জানি"
  Comparison: both sides Unicode-NFC normalized, trimmed, inner whitespace collapsed, English compared case-insensitively. Delete enables only on a match; then the password field; then Delete (red, the only red element). The phrase is a guard in the app; the server checks the password.
- API: DELETE /users/me {password} stays (same contract); its behavior changes from hard delete to de-identify. UsersService.deleteAccount becomes, in one transaction:
  - Erased: phone = NULL, passwordHash = random unusable hash, name = "Deleted user" (the app and panel also translate it; stored as a fixed marker), address = NULL, dateOfBirth = NULL after birthYear = its year, upazilaId = NULL, languagePreference kept, switches off; health records, health reminders, AI health suggestions, assistant conversations (cascade), notifications, device tokens (after the session_ended push), password reset code; family membership and invitations sent (and invitations addressed to their old phone).
  - Kept, linked to the unnamed row: prescriptions (structured data: doctor, visit, diagnosis, tests, medicine lines, dates, statuses), routines and doses (history), gender, birthYear, division, district, audit rows, doctor / medicine patient counts.
  - Pending work: PENDING and AWAITING_CONFIRMATION prescriptions are deleted (they leave the pharmacist queue; their images too); active routines set active = false and future PENDING doses deleted.
  - accountStatus = DELETED, deletedAt = now. Audit user.delete (subject = the placeholder id, no personal data in before/after).
  - Prescription images of all their prescriptions are deleted from Cloudinary after the commit (best effort, as today); imageUrl on kept prescriptions is set to NULL first (nullable from SQL 009) so no response points to a deleted image; PrescriptionImageUrlInterceptor and the panel handle NULL.
  - Family: if they were caregiver, handover (C3); if they were the last member, the family is removed; a LEFT event is written ("Deleted user has left").
- Sign-up with the same phone later: a new, empty account (the old row has phone NULL). Nothing can be restored.
- Analytics and counts: user totals exclude DELETED (as now) and show Active / Deactivated / Suspended separately; doctor / medicine patient counts now INCLUDE deleted patients (catalog/lib/patient-counts.ts and admin-analytics drop the DELETED filter there); age bands use birthYear when dateOfBirth is NULL.
- Staff screens show "Deleted user" and no phone wherever the patient appears (prescription detail, routines panel, AI suggestions, audit log).

B3. Ban / Unban (admin panel)
- Uses SUSPENDED. Admins may ban USER and PHARMACIST accounts; never ADMIN accounts (including their own), so the only admin can't lock everyone out.
- API (ADMIN only): POST /admin/users/:id/ban and /unban. Ban: accountStatus = SUSPENDED, suspendedAt = now, passwordChangedAt = now (signed out everywhere), session_ended push, future PENDING doses deleted and dose generation paused (as deactivation). Unban: ACTIVE, suspendedAt = null. Both audited (user.ban / user.unban, actor = admin). Banning a DEACTIVATED user works; unbanning returns ACTIVE.
- A banned user behaves like a deactivated one everywhere except login: family sees "Account paused", caregiver features pause, no pushes.
- Login: wrong password → the usual "Invalid phone number or password" (no account probing). Right password on SUSPENDED → 403 "This account is under suspension. Please contact Medi-Bela Authority." (app and panel show it, both languages in the app). Login never lifts a ban. SMS reset on a banned account stays silent and never reactivates.
- A banned pharmacist's past work stays (prepared prescriptions, "Created by", notices, audit rows).

C. Family

C1. Leave (any member, from Settings → Privacy & family)
- API: POST /family/leave. Confirm dialog in the app. Effects: membership removed; if they were caregiver → C3; invitations they sent cancelled; if no members are left the family is removed; LEFT event; audit family.leave. Afterwards they can create a family or accept another invitation.
- Past missed-dose alerts already in other members' inboxes stay.

C2. Remove (caregiver only, from the family screen)
- API: DELETE /family/members/:userId (CAREGIVER only; not themself, they use Leave). Confirm dialog. Effects: membership removed; REMOVED event (actor = caregiver); audit family.remove; the removed member gets a neutral push/inbox item "You were removed from the family" (SYSTEM notification, data.kind family_removed).
- Invite stays caregiver-only (already enforced in FamilyService.inviteMember).

C3. Caregiver handover (caregiver leaves or deletes the account)
- The member with the earliest joinedAt (ties: lowest id) becomes CAREGIVER; the old caregiver's pending invitations are cancelled; CAREGIVER_CHANGED event; audit family.caregiver_change; every remaining member gets a neutral push "<name> is now the family caregiver" (the role decides who gets the caregiver tools).
- A deactivated or banned caregiver stays caregiver (no handover).

C4. Activity feed (family screen)
- GET /family/events?cursor= (members of that family only; 10 per page, "Load more", keyset createdAt DESC, id DESC).
- Lines (EN / BN): "<name> has joined" / "<name> পরিবারে যোগ দিয়েছেন"; "<name> has left" / "<name> পরিবার ছেড়ে গেছেন"; "<name> was removed by <caregiver>" / "<caregiver> <name>-কে পরিবার থেকে সরিয়েছেন"; "<name> is now the caregiver" / "<name> এখন পরিবারের তত্ত্বাবধায়ক"; "Family created by <name>" / "<name> পরিবারটি তৈরি করেছেন". Deleted user shows "Deleted user" / "মুছে ফেলা ব্যবহারকারী".
- Written by: createFamily (CREATED), acceptInvitation (JOINED), leave (LEFT), remove (REMOVED), handover (CAREGIVER_CHANGED), account delete (LEFT). Existing families get no back-filled history.
- Pushes: only the removed member (C2) and the caregiver change (C3). Joins and leaves appear only in the feed. (Approved by the owner 2026-10-30.)

D. Admin panel: users and prescriptions
- New page Users (/super-control-007/users; sidebar under Admin): GET /admin/users?cursor=&phone=&divisionId=&ageBand=&role=&status= (ADMIN only, 20 per page, keyset createdAt/id). Phone search accepts 01…, +8801… or part of a number (digits compared after normalizePhone where complete, contains otherwise). Filters: division, age band (0-17 / 18-39 / 40-59 / 60+, from dateOfBirth or birthYear), role (Patient / Pharmacist; admins are listed but can't be banned), status (Active / Deactivated / Suspended; Deleted hidden unless chosen). Each row: name, phone, role, division, status badge, Ban / Unban button with a confirm dialog. No ban reason field (not wanted).
- Prescriptions: the admin list page and its sidebar link are removed. The read-only detail page (/super-control-007/prescriptions/[id]) stays, reachable only from an audit-log entry's "Open record". Admin dashboard: the pending count and the recent list stop linking. GET /prescriptions/admin/queue stays (the pharmacist queue uses it).

E. Panel redesign (frontend; plain CSS and tokens, no new packages)
E1. Sign-in page (replaces the split layout)
- One soft background across the whole page (radial teal and blue glows over the --color-bg token; separate dark values), no hard divider.
- Left (wide screens only): logo, headline "Every prescription checked. Every dose on time." (chosen by the owner 2026-10-30), supporting line "Review prescriptions, keep the medicine catalog right, and reach patients with timely notices, all in one place.", and the signature visual: three floating, slightly rotated cards that tell the product's story:
  1. a prescription line "Napa 500 mg · 1+0+1 · after meal" with a green "Checked by pharmacist" dot;
  2. a reminder "8:00 AM · 2 medicines" with a "Taken" chip;
  3. a family alert "Missed dose · family notified" with an amber dot.
  A footer line with a small icon: "Alarm-style reminders for patients, and family who know when a dose is missed."
- Form card: title "Sign in", subtitle "Medi-Bela Management · for pharmacists and admins", fields and button unchanged. English only (the panel has no language switch).
- Right: the form on a floating card (same fields), theme switch top-right. Phones: logo above the card, no visual.
E2. Internal look (from the owner's canvas "Medibela Admin Panel Redesign": look only, none of its extra features such as claim locks, plans, shifts, staging, team roles)
- Fonts: IBM Plex Sans + Hind Siliguri (Bengali) through next/font/google (bundled at build time, no runtime Google request, no new dependency). Numbers in tables may use tabular figures.
- Tokens: background soft green-grey (#F4F7F6 light), surface white, border #DDE5E3, primary teal #0B6E63 / hover #075048, text #10201C, muted #4A5B57; status pairs (amber #FDF1E3/#8A4200, blue #E8EFFC/#1849A9, red #FDECEA/#B42318, green #E6F4EA/#0F6B37, grey #EEF1F0/#33443F); matching dark values. Colors only through tokens (convention kept).
- Sidebar: brand (logo mark + wordmark, caption = role area), section labels (Pharmacist: WORK = Dashboard, Prescriptions [pending badge], Routines, AI suggestions [drafts badge], Notices [sent-back or pending badge]; CATALOG = Doctors, Medicines, Health rules. Admin: OVERVIEW = Dashboard; CONTENT = Notices [waiting badge]; RECORDS = Doctors, Medicines; ADMIN = Users, Audit log), user card at the bottom (initials avatar, name, role, Log out). Badge counts come from the existing dashboard endpoints, fetched once per page load.
- Page header: 28px title, one-line subtitle, actions and the theme switch on the right.
- Stat cards: grid auto-fit minmax(180px), 12px radius, label above value.
- Lists: tables on wide screens (uppercase 12px headers, row hover, status pills), turning into stacked cards under 640px; wide tables scroll inside their box. Tabs with count pills where lists have statuses.
- Every page keeps its behavior, routes and API calls; only markup classes and CSS change. Checked at 1440, 1024, 768 and 375 px in light and dark.

F. App (Flutter)
F1. Bottom navigation: Home · Medicines · Family · Health · Profile
- Medicines tab = today's doses, My medicines and Prescriptions under one tab (segmented control at the top: Today / My medicines / Prescriptions); old routes /prescription, /prescription/today and /medicines redirect there so pushes and links keep working.
- Health tab = readings, health reminders, suggestions (as today).
- Inbox = bell with an unread badge on Home's top bar (no tab). Assistant = a large card on Home.
- Labels always visible (one short word, app language), large icons and tap areas, clear selected state; five tabs, no ☰ menu; a screen always lives under the same tab.
F2. Back behavior
- Detail screens are pushed (context.push), tab roots are switched (context.go); back always returns to the previous screen; from a tab root back goes to Home.
- Home and Login: the first back shows a SnackBar "Press back again to exit" / "বের হতে আবার চাপুন"; a second press within 2 seconds closes the app; after that it starts over. Register, Forgot and Reset password go back to Login.
- Closing the app never affects reminders (OS alarms).
F3. Profile
- Identity card (name, phone, family role), Settings, then Log out last and set apart, with an "Are you sure?" dialog. No quick links, no app version.
F4. Settings (new screen /profile/settings; existing screens reused)
- Account: Edit details, Change password.
- Reminders & notifications: Reminder check first, with a status dot and text (green "All good" / orange "Needs attention", from ReminderStatusController); then Push notifications, Medicine reminders, Notices.
- Privacy & family: Hide from family; Leave family (only when in a family; confirm dialog).
- Appearance & language: Language first, then Theme. No text-size setting (the app follows Android's own font size; a custom scale could break fixed layouts without device testing).
- Account actions: Deactivate account, Delete account (only the Delete button is red).
F5. Account flows in the app: deactivate dialog (password), delete screens (B2), "Welcome back" after reactivation, suspension message on login, session_ended handling in foreground and background isolate (cancel reminders, clear Drift and secure storage).
F6. Family screen: activity feed (C4, Load more), member rows show "Account paused" for deactivated or banned members, caregiver sees Remove on each member (confirm dialog).
F7. Strings (EN / BN), all in app_strings.dart, existing terms reused:
- Settings / সেটিংস; Account / অ্যাকাউন্ট; Edit details / তথ্য সম্পাদনা; Change password / পাসওয়ার্ড পরিবর্তন করুন
- Reminders & notifications / রিমাইন্ডার ও নোটিফিকেশন; Reminder check / রিমাইন্ডার পরীক্ষা; All good / সব ঠিক আছে; Needs attention / মনোযোগ প্রয়োজন
- Privacy & family / গোপনীয়তা ও পরিবার; Hide from family / পরিবার থেকে লুকান; Leave family / পরিবার ছেড়ে দিন; Remove from family / পরিবার থেকে সরান
- Appearance & language / ভাষা ও রঙের ধরন
- Account actions / অ্যাকাউন্ট সংক্রান্ত; Deactivate account / অ্যাকাউন্ট সাময়িক বন্ধ করুন; Delete account / অ্যাকাউন্ট মুছুন; Deactivate instead / বরং সাময়িক বন্ধ করুন; Continue to delete / মুছে ফেলতে এগিয়ে যান
- Account paused / অ্যাকাউন্ট বন্ধ আছে; Welcome back / আবার স্বাগতম; Deleted user / মুছে ফেলা ব্যবহারকারী
- This account is under suspension. Please contact Medi-Bela Authority. / এই অ্যাকাউন্টটি স্থগিত আছে। মেডি-বেলা কর্তৃপক্ষের সাথে যোগাযোগ করুন।
- Are you sure you want to log out? / আপনি কি লগ আউট করতে চান?
- Press back again to exit / বের হতে আবার চাপুন
- Tabs: Home / হোম, Medicines / ওষুধ, Family / পরিবার, Health / স্বাস্থ্য, Profile / প্রোফাইল; Medicines segments: Today / আজ, My medicines / আমার ওষুধ, Prescriptions / প্রেসক্রিপশন
The owner reviews this table before F ships.
F8. App sign-in visual (approved by the owner 2026-10-30)
- Login screen only (Register is a long form; Forgot / Reset stay plain): logo, then the three cards from the web sign-in page as a compact, gently overlapping stack (small tilt, no motion) in their own area ABOVE the form: the form starts below the visual with clear space between them, and no card overlaps the form or its fields (owner's choice 2026-10-30). App language and theme colors.
- Cards: "Napa 500 mg · ১+০+১ · খাবারের পরে" / "ফার্মাসিস্ট যাচাই করেছেন"; "সকাল ৮:০০ · ২টি ওষুধ" / "খাওয়া হয়েছে"; "ডোজ বাদ পড়েছে" / "পরিবারকে জানানো হয়েছে" (English: Checked by pharmacist, 8:00 AM · 2 medicines / Taken, Missed dose / Family notified). One line under them: "Right time, healthy life" / "সঠিক সময়, সুস্থ জীবন".
- The visual hides while the keyboard is open and on short screens (height < 640 dp), so the phone and password fields and the Sign in button never move off screen; it is decoration only (excluded from screen readers).

G. Checks
- Backend unit tests: deactivate / reactivate (login and reset), delete (erased vs kept fields, pending prescriptions gone, patient counts still include them, phone free for a new sign-up), ban / unban (login message only after a correct password, reset silent, admin can't ban an admin), RollingDoseJob skips non-ACTIVE, family leave / remove / handover / events, admin users filters, role matrix (staff-roles.spec).
- DB-backed specs (admin.int, users, family) where TEST_DATABASE_URL is available.
- Panel build; browser check of sign-in and every redesigned page at four widths, light and dark (signed-in pages need a staff test account in a local/staging setup).
- Mobile: flutter analyze, flutter test (new: back-to-exit, settings sections, delete phrase matching incl. Bengali normalization, session_ended handler), release build. Phone testing stays deferred.
- Update CLAUDE.md and plan.md; commit on main.

Decisions while starting the build (2026-10-30):
- Dose resume: pausing an account (deactivate / ban) deletes future PENDING doses AND sets generatedUntil = now on its active routines; RollingDoseJob never generates before now; reactivation (login or SMS reset) and unban extend that user's routines immediately, so reminders return at sign-in and no past doses are back-filled.
- Home (top to bottom): reminder warning banner (only when needed), Today's medicines, Health reminders, a large full-width Upload prescription button (icon + text), a large Assistant card, Notices, ad banner. The Quick actions row is removed (Family is its tab). Diabetes becomes a clear row near the top of the Health tab.
- F7 strings: the owner reviews the table again when part F starts (build A-E first, then stop). Approved as written 2026-10-30; caregiver in Bengali is পরিচর্যাকারী everywhere (C4's "তত্ত্বাবধায়ক" line uses পরিচর্যাকারী instead).
- Commits: one commit on main at the end of the round.
Built (2026-10-30):
- Backend: deactivate (POST /users/me/deactivate), de-identifying delete (DELETE /users/me, same contract), ban / unban (POST /admin/users/:id/ban|unban), reactivation on login (reactivated: true) and SMS reset, suspension message after a correct password, SMS reset silent for banned accounts; session_ended push + device tokens dropped on every pause; pauseSchedules / resumeSchedules and RollingDoseJob (ACTIVE only, never before now); family leave / remove / handover / feed (FamilyMembershipService, family_events), paused members; GET /admin/users (phone, division, age band, role, status); patient counts include deleted patients, age bands fall back to birthYear, user totals by status; dashboard notice counts for the sidebar badges (pharmacist notices.sentBack/pending, admin analytics.noticesAwaitingApproval).
- Panel: Users page; admin prescriptions list removed (the detail page goes back to the audit log); "Photo deleted"; phone hidden when null (PatientName); redesign: tokens, fonts, sidebar sections / badges / user card, page header subtitle, stat cards (label above value), underline tabs with count pills, DataList tables (cards under 640px), new sign-in page.
- App: tabs Home · Medicines · Family · Health · Profile; Medicines tab with Today / My medicines / Prescriptions (old routes redirect); back rules and press-back-twice on Home and Login; Home: Upload prescription button (opens the upload form), Assistant card, Quick actions removed; Diabetes row on Health; Profile (identity card with family role, Settings, Log out); Settings (five sections, Reminder check status dot, Leave family, offline-disabled account actions); deactivate dialog; two delete screens with the sentence check (EN / BN, Bengali NFC rules in code); Welcome back; suspension message in both languages; session_ended handled in the foreground (logout) and in the background isolate (reminders cancelled, Drift and secure storage cleared); family feed, Remove member, Account paused; sign-in cards above the form (hidden with the keyboard open or under 640 dp).
Checked: backend lint (3 old warnings), 291 unit tests, build; DB-backed specs NOT run (no TEST_DATABASE_URL). Panel build; browser: sign-in at 1440 and 375 px in light and dark, the Users page with stubbed data at 1440 (light) and 375 (dark). Mobile: analyze (no errors or warnings; 2 new infos match the surrounding style), 54 tests incl. back-to-exit, tab mapping, settings sections, delete sentence (Bengali), session_ended wipe; release APK builds.
Not done / open:
- Phone testing (deferred, as for every round); the new app screens are checked by analyze and widget/unit tests only.
- Signed-in panel pages other than Users were not looked at in a browser (needs a running API and a staff account; no second API on Neon). The two top-10 lists inside the analytics section keep the old card rows.
- A paused account's routines from before Round 4 (no scheduleTimes) keep their future doses (can't be regenerated); none exist on the fresh Neon database.
- "Account paused" comes from the server only (the Drift member cache has no column for it), so it doesn't show offline.
- Profile no longer shows the routine / prescription summaries or the sync status (F3); the logout dialog still warns about unsent changes.
- Drafted strings, not in the F7 table (EN / BN), for the owner to review: deleteWarningTitle "Before you delete" / "মুছে ফেলার আগে"; deleteErasedHeading / deleteErasedList; deleteKeptHeading / deleteKeptList; deleteCannotUndo; deactivateHint; deleteConfirmTitle; deletePhrasePrompt; deactivateExplain; deactivateAction "Deactivate" / "সাময়িক বন্ধ করুন"; leaveFamilyConfirm; leaveAction; removeMemberConfirm; removeAction; familyActivity "Family activity" / "পরিবারের কার্যক্রম"; noFamilyActivity; assistantCardSubtitle "Ask about your medicines and health" / "ওষুধ ও স্বাস্থ্য নিয়ে প্রশ্ন করুন"; familyMemberRole "Family member" / "পরিবারের সদস্য"; push texts "You were removed from the family." / "আপনাকে পরিবার থেকে সরিয়ে দেওয়া হয়েছে।" and "<name> is now the family caregiver." / "<name> এখন পরিবারের পরিচর্যাকারী।" (all in app_strings.dart / notification-messages.ts).
Round 11: Errors, loading and empty states, 404 and offline, privacy, support, about - CODE DONE 2026-10-31, device testing pending
Today (found in the code):
- Panel: no app/not-found.tsx, error.tsx or loading.tsx; 24 files show the backend's raw message in an .error-banner; 22 places show a plain "Loading…"; no offline detection.
- App: widgets/state_views.dart (LoadingView, ErrorView, EmptyView) used in about 16 files, others use a bare spinner; connectivity_plus with ConnectivityBanner ("You're offline — showing saved data"); go_router has no errorBuilder (unknown route or bad deep link shows go_router's default error screen); backend errors are English only.
- No privacy, terms, support or about pages. The app has a sponsored ad banner widget (widgets/sponsored_ad_banner.dart); no ad network is wired. Ads are out of scope for now (owner, 2026-10-30): the privacy text says nothing about ads and the widget is left as it is.

A. Error handling (panel and app)
- Tone: short, friendly, with a way out. Example: "Couldn't load your medicines. Check your connection and try again." [Try again] / "আপনার ওষুধের তালিকা আনা যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।" [আবার চেষ্টা করুন].
- Backend: every error response gains a machine-readable `code` (e.g. PASSWORD_INCORRECT, ACCOUNT_SUSPENDED, NOT_FOUND, RATE_LIMITED, VALIDATION_FAILED, SERVER_ERROR) next to the existing `message` (additive; common/filters/http-exception.filter.ts plus the services that throw). Unexpected errors (5xx) also carry a short `ref` (e.g. 7KQ2-M9) that is written to the server log with the stack trace (no personal data), so support can find it.
- App: one mapper from code (and HTTP status / Dio error type) to bilingual text in app_strings.dart; unknown codes fall back to a generic message; 5xx shows "Something went wrong. Ref: 7KQ2-M9". 401 → sign-in with "Your session ended. Please sign in again." (429 keeps its pause-and-retry rule in the sync queue.)
- Panel: lib/api-client.ts maps codes to English text; page-load failures show an inline banner with [Retry]; actions (save, publish, ban…) show a small toast ("Saved", "Couldn't save. Try again.") that disappears after a few seconds; forms keep field errors next to the field. A small toast component in components/ (no package).

B. Loading and empty states
- Loading: skeletons (grey placeholder shapes in the layout of the real content, gentle pulse, respects reduced motion) for lists, tables, dashboards and detail pages; a small spinner inside a button while its action runs (button disabled). Panel: components/skeleton.tsx + CSS; app: a Skeleton widget in widgets/state_views.dart replacing bare spinners.
- Empty states: line icon (no image files), one line, and the next action where there is one. Examples: "No prescriptions yet" [Upload prescription]; "No medicines today"; "No family yet" [Create family] / [Check invitations]; "No readings yet" [Add reading]; "Inbox is empty"; panel "Queue is clear" (no button). Every list in the panel and the app is covered; texts in EN and BN.

C. 404, crashes, maintenance, offline
- Panel: app/not-found.tsx (branded "Page not found" + [Go to dashboard], or [Sign in] when signed out) and app/error.tsx ("Something went wrong" + [Try again], with the ref when known).
- Maintenance: when the API answers 503, the app and panel show a full-screen "Medi-Bela is being updated. Please try again in a few minutes." / "মেডি-বেলা আপডেট হচ্ছে। কয়েক মিনিট পর আবার চেষ্টা করুন।" with [Try again]. (Backend: an optional MAINTENANCE_MODE env that returns 503 on every route except /health; added to .env.example.)
- App offline: offline-capable screens (Home, Medicines, readings, and the Support, Privacy and About pages, whose text ships with the app) keep the banner; online-only screens (prescription upload, family and caregiver screens, Assistant, Settings actions, notices) show a full-screen "No internet connection" / "ইন্টারনেট সংযোগ নেই" with [Try again], and recover by themselves when the connection returns.
- Panel offline: a top banner "You're offline. Changes can't be saved until you're back online." (navigator.onLine + online/offline events).
- App unknown route or bad deep link: go_router errorBuilder → "Page not found" / "পাতাটি পাওয়া যায়নি" + [Go to Home].

D. Privacy & terms (one page, EN and BN)
- App: Settings → Help & about → Privacy & terms. Web: public page <frontend_url>/privacy (no sign-in, outside the role layouts; this is the Play Store privacy URL), with a language switch (English | বাংলা).
- Content: generic only. No company name, address or legal contact, not even a placeholder (the owner adds them later).
- Owner's lines (approved):
  1. Your data is stored under strong monitoring and a strict access policy. / আপনার তথ্য কঠোর নজরদারি ও কড়া প্রবেশাধিকার নীতির অধীনে সংরক্ষিত থাকে।
  2. Your data is used for medical purposes only. / আপনার তথ্য শুধু চিকিৎসা-সংক্রান্ত কাজে ব্যবহার করা হয়।
  3. No third party gets access to your health data for promotion or research. / কোনো তৃতীয় পক্ষকে প্রচার বা গবেষণার জন্য আপনার স্বাস্থ্য-তথ্য দেওয়া হয় না।
  4. Medi-Bela is not a replacement for your regular doctor or health service. / মেডি-বেলা আপনার নিয়মিত ডাক্তার বা স্বাস্থ্যসেবার বিকল্প নয়।
- Added lines (approved 2026-10-30):
  5. Only you, the family members you allow, and the Medi-Bela pharmacists who check your prescription can see your medicine information. / শুধু আপনি, আপনার অনুমতি দেওয়া পরিবারের সদস্যরা এবং প্রেসক্রিপশন যাচাইকারী মেডি-বেলা ফার্মাসিস্টরাই আপনার ওষুধের তথ্য দেখতে পারেন।
  6. Trusted service providers that run parts of the app (photo storage, notifications, AI answers, SMS) process data only to provide those services. / অ্যাপের কিছু অংশ চালাতে বিশ্বস্ত সেবাদাতারা (ছবি সংরক্ষণ, নোটিফিকেশন, এআই উত্তর, এসএমএস) শুধু সেই সেবা দিতেই তথ্য ব্যবহার করে।
  7. Your password is stored encrypted; no one at Medi-Bela can see it. / আপনার পাসওয়ার্ড এনক্রিপ্ট করে রাখা হয়; মেডি-বেলার কেউ তা দেখতে পারে না।
  8. You can hide yourself from family, deactivate, or delete your account at any time from Settings. Deleting erases your personal details. / সেটিংস থেকে যেকোনো সময় পরিবার থেকে লুকাতে, অ্যাকাউন্ট সাময়িক বন্ধ বা মুছে ফেলতে পারেন। মুছে ফেললে আপনার ব্যক্তিগত তথ্য মুছে যায়।
  9. The AI assistant gives general health information only. It does not diagnose or prescribe. / এআই সহকারী শুধু সাধারণ স্বাস্থ্য-তথ্য দেয়; এটি রোগ নির্ণয় বা ওষুধ নির্ধারণ করে না।
  10. Always take medicines as your doctor advised. If something looks wrong, ask your doctor or pharmacist first. / সবসময় ডাক্তারের পরামর্শ অনুযায়ী ওষুধ খান। কিছু ভুল মনে হলে আগে ডাক্তার বা ফার্মাসিস্টকে জিজ্ঞেস করুন।
  11. In an emergency, call 999 or go to the nearest hospital. / জরুরি অবস্থায় ৯৯৯-এ কল করুন বা নিকটস্থ হাসপাতালে যান।
- Page order: data and privacy lines (1-3, 5-8), then terms of use and medical disclaimer (4, 9-11).
- Sign-up consent: a required checkbox "I agree to the Privacy & terms" / "আমি গোপনীয়তা ও শর্তাবলিতে সম্মত" linking to the page; Register stays disabled until it is ticked. The server records when the user agreed (users.termsAcceptedAt, pending SQL 010, approved) as proof of consent; existing users are not asked again.

E. Support (app: Settings → Help & about → Support; web: sidebar Support and public <frontend_url>/support)
- How to use the app: short step lists with the matching screen names: upload a prescription and confirm it; take or snooze a dose (Done / Later); add your own medicine; create a family and invite; hide from family; Reminder check; change language and theme.
- FAQ (drafted, 6-8): reminders don't ring (→ Reminder check, battery, Alarms & reminders); prescription rejected (→ read the note, Re-upload); dose time wrong (→ edit in My medicines); family can't see me (→ Hide from family is on); forgot password (→ SMS reset); deactivate vs delete; is my data safe (→ Privacy & terms).
- Contact: +8801810314801 and +8801763740720, each with [Call] (tel:) and [WhatsApp] (https://wa.me/8801810314801, https://wa.me/8801763740720). Opening the dialer and WhatsApp from the app uses the url_launcher package (official Flutter package; approved by the owner 2026-10-30). Numbers also have a copy button.
- No "Report a problem" form (not asked for).

F. About us (app: Settings → Help & about → About us; web: public <frontend_url>/about)
- Mission: "Care for your family, even from far away." / "দূরে থেকেও পরিবারের যত্ন নিন।"
- Vision: "Health, On Time" / "ঠিক সময়ে, সুস্থ জীবন"
- Goal lines (draft, EN / BN):
  - Turn every pharmacist-checked prescription into reminders that ring on time. / ফার্মাসিস্টের যাচাই করা প্রতিটি প্রেসক্রিপশনকে সময়মতো বাজা রিমাইন্ডারে রূপ দেওয়া।
  - Let families know when a dose is missed, so no one has to worry alone. / ডোজ বাদ পড়লে পরিবার যেন জানতে পারে, যাতে কাউকে একা দুশ্চিন্তা করতে না হয়।
  - Keep health records, notices and trusted health information in one simple app, in Bangla and English. / স্বাস্থ্যের রেকর্ড, বিজ্ঞপ্তি আর নির্ভরযোগ্য স্বাস্থ্য-তথ্য এক সহজ অ্যাপে, বাংলা ও ইংরেজিতে।
- Team, two columns (one column on narrow phones), round photo, name, field, university, Facebook link:
  - Left: ashraful.jpg; Ashraful Alam; Software Engineering; Shahjalal University of Science and Technology, Sylhet; https://www.facebook.com/ashraful.alam.931253
  - Right: tanvir.jpg; Tanvir Hossain; Chemical Engineering; Rajshahi University of Engineering and Technology, Rajshahi; https://www.facebook.com/aztanvirhossain
  - Bangla (confirmed): আশরাফুল আলম, সফটওয়্যার ইঞ্জিনিয়ারিং, শাহজালাল বিজ্ঞান ও প্রযুক্তি বিশ্ববিদ্যালয়, সিলেট; তানভীর হোসেন, কেমিক্যাল ইঞ্জিনিয়ারিং, রাজশাহী প্রকৌশল ও প্রযুক্তি বিশ্ববিদ্যালয়, রাজশাহী.
- Photos (the owner shows them; approved): the owner puts ashraful.jpg and tanvir.jpg in mobile/assets/images/ (next to logoBn.png / logoEn.png) and the same files in frontend/public/ for the web page; resized to 320×320 and compressed before shipping (keeps the APK small). Facebook links open in the browser (url_launcher, same question as in E).

G. Placement
- App Settings gains a section "Help & about" / "সাহায্য ও পরিচিতি" (last before Account actions): Support, Privacy & terms, About us.
- Panel: Support in the sidebar (both roles); Privacy & terms and About us links in the sign-in page footer; the three public pages share a simple header (logo) and footer.

H. Checks
- Backend: error filter codes and refs (unit), MAINTENANCE_MODE (unit), consent field on register (unit + DB spec where available).
- Panel: build; browser check of not-found, error page, offline banner, toasts, skeletons and empty states, /privacy, /support, /about at four widths in light and dark.
- App: analyze; tests for the error mapper (codes → EN/BN), errorBuilder route, consent checkbox, Support links; release build.
- Update CLAUDE.md and plan.md; commit on main.

Built (2026-10-31):
- Backend: every error response has `code` (common/filters/error-codes.ts; specific codes for wrong password / credentials, suspended, not active, reset code, phone taken) and, on unexpected 5xx, a `ref` logged with the stack; the log line and response `path` no longer include the query string (it can hold a phone number). MAINTENANCE_MODE (MaintenanceGuard, first APP_GUARD; /health exempt; .env.example). Sign-up requires acceptTerms: true and stores users.termsAcceptedAt (pending SQL 010, applied to Neon).
- Panel: api-client maps codes to English (network failures included); toasts for actions; Retry on load failures; skeletons for lists, details and dashboards; button spinners; empty states with a line icon ("Queue is clear"); app/not-found.tsx and app/error.tsx; offline banner; maintenance screen on any 503; public /privacy, /support, /about (English | বাংলা, shared header and footer); Support in the sidebar; Privacy & terms and About us under the sign-in form.
- App: error mapper (codes → EN/BN, Ref on 5xx); "Your session ended" on Login after a 401; maintenance screen over the app on 503; skeletons (LoadingView) instead of spinners; empty states with actions (Upload prescription, Add record, Inbox is empty); full-screen "No internet connection" on family, caregiver, assistant and confirm-prescription screens; "Page not found" (go_router errorBuilder); Settings → Help & about (Support with Call / WhatsApp / Copy, Privacy & terms, About us; offline); sign-up consent checkbox linking to Privacy & terms (open while signed out); url_launcher.
- Text for Privacy & terms / Support / About: docs/content/public-pages.json → build_public_content.py → panel and app files. Team photos resized to 320×320 (frontend/public and mobile/assets/images/team/).
Checked: backend lint (only the old warning), 303 unit tests incl. new error-filter, maintenance and consent specs, build; DB-backed specs NOT run (no TEST_DATABASE_URL; test helper signupDetails now sends acceptTerms). Panel build; browser: /about and /support at 1440 light, /privacy in Bengali at 375 dark, 404 page, offline banner. Mobile: analyze (no errors or warnings), 65 tests incl. error mapper EN/BN, page not found, consent, Support fallback, About in Bengali; release APK.
Not done / open (owner):
- Owner decisions 2026-10-31: the unused full-size photos were deleted (only the 320x320 copies ship); own prescription upload and Notices stay offline-capable (upload queued, saved notices shown), on purpose; Render's DOSE_MISSED_GRACE_MINUTES is 62; drafted texts not commented on are accepted.
- Shortened by the owner 2026-10-31: delete screen 1 shows one sentence ("Deleting your account will erase all your information, and it can't be undone." / "অ্যাকাউন্ট ডিলিট করলে আপনার সব তথ্য মুছে যাবে এবং তা পুনরায় ফিরিয়ে আনা সম্ভব নয়।") plus Deactivate instead / Continue to delete; deactivate dialog: "This will pause your activity." / "এটি আপনার কার্যক্রম বন্ধ রাখবে।"; Leave family: "Are you sure?" / "আপনি কি নিশ্চিত?".
- Panel ESLint set up 2026-10-31 (owner's yes): eslint 9 + eslint-config-next 15.5 + @eslint/eslintrc, `npm run lint` = `eslint .`; the 8 first findings fixed (unused imports, three effects now depend on a useCallback load, autosuggest aria-controls).
- DB-backed specs run 2026-10-31 on a Neon branch of main (TEST_DATABASE_URL in backend/.env, a separate endpoint; main untouched): 97 of 98 pass with --runInBand --testTimeout=300000. Two expectations updated for Round 10 behaviour (rolling-dose: no dose before now, so 27 not 28; family summary has paused: false). The one failure is latency only: "alerts the family for every missed dose in one run, beyond one batch" sends 400 of 500 within the job's 45 s run budget from this PC to Neon Singapore (the next run sends the rest); it passed on a local Postgres in Round 9. Delete the Neon test branch when no longer needed.
- Fixed 2026-10-31 (owner): confirming a prescription or adding a medicine no longer creates doses for times already past (planSchedule skips them, by date and time; the course keeps its dates). Tests: routine-generation.service.spec "only future doses" (failed before).
- Drafted text for review (EN / BN): Support how-to steps and FAQ answers, the error messages (errorNetwork ... errorGeneric, sessionEnded), noInternetHint, couldNotOpenLink, About headings ("What we work for", "Team", BN "আমরা যা চাই", "দল", vision label "স্বপ্ন"), panel 404 / error page lines.
- Signed-in panel pages with toasts / skeletons were not looked at in a browser (no API with a staff account); not run on a phone.
- The response field `path` now omits the query string (no client reads it).

After Round 11 (2026-10-31): prescription photo fixes - CODE DONE
- Fixed (owner): pharmacists saw no prescription photo, and "open full size" showed Cloudinary's "public_id ... is invalid". Stored URLs end in the SDK's `?_a=...` tag, which parseCloudinaryImageUrl read as part of the public id, so every signed link (and the photo delete at account deletion) named a missing image. The query string is now dropped before parsing; stored rows need no change. Tests: prescription-image-url.spec, two cases with `?_a=` (failed before).
- The app shrinks prescription photos before upload (features/prescription/domain/prescription_photo.dart: at most 2000 px on the long side, quality 80; own upload and caregiver upload), so a photo is a few hundred KB instead of 3-8 MB.
- Considered, not built (owner agreed 2026-10-31): direct signed upload from the phone to Cloudinary (backend signs, phone uploads, backend checks Cloudinary's answer and saves). Saves server memory and bandwidth, but adds a three-step flow, orphaned uploads to clean up, size limits moved to a Cloudinary upload preset, and changes to the offline queue, caregiver upload and Re-upload. Revisit if uploads strain the Render instance (memory alerts, slow uploads).
- Checked: backend lint (old warnings only), unit specs, build; mobile analyze (no new issues; three older unused-import warnings in app_router.dart and test/auth/session_ended_test.dart left alone), 65 tests, release APK. Not checked in a browser or on a phone (the panel needs a signed-in pharmacist and real Cloudinary images).
