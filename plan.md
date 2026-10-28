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
Built: grouped alarm-style reminders (ring 2 min, silent copy, repeat +30), Done/Later with the app closed (Later 30 min, max twice; snoozes survive restarts), neutral lock-screen text, medicine-reminders and notices switches (users.medicineRemindersEnabled / noticesEnabled, migration 20261029120000), notice push respects its switch (moved here from Round 7), backstop push at +30 (data-only, dropped by the app if taken locally), family alert at +62 and none when reminders are off, inbox tabs Personal / Family / General.
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
Round 4: Data foundation
User fields and geo tables, then Doctor, Medicine, DiagnosticTest and the doctor-genre list.
New prescription statuses and structured medicine lines, routine columns and AuditLog.
Notice fields and the privacy flag.
Rolling dose generation, the cursor pagination helper, and the write-light indexes.
Migrate existing prescriptions and routines to active, so no reminders stop.
Done when: migrations pass on a copy of real data and the specs are green.
Round 5: Pharmacist portal
The prescription form from your plan: doctor block, medicine form, diagnosis form, next visit date, and “Add new” collapsing the previous entry to one line.
Autosuggest for medicines and tests, and a portal where pharmacists complete doctor and medicine records.
Reject with feedback and a linked re-upload, then send for confirmation. Queues are paginated at 20.
Done when: a prescription goes from upload to AWAITING_CONFIRMATION and doctor-to-medicine rows are correct.
Round 6: User app
The Confirm or Edit screen. Routines and doses are created at confirm.
Manual routine create, edit and remove, with “self-added” and “edited by you” labels.
Caregiver actions with audit entries, the invitation warning, the privacy flag, and the new registration fields.
Larger buttons and basic colors, and 10-row “Load more” lists.
Done when: a user and a caregiver can complete the whole flow end to end.
Round 7: Notices and admin shell 
One login that redirects by role. Pharmacists go to the current dashboard and admins to different dashboard protected by unique url extension, with server-side checks.
Notice form with source display. A pharmacist drafts, an admin approves, and admin-created notices publish directly.
A start-date job, division filtering, and General-tab polish (the notice push switch and the General tab shipped in Round 3).
Done when: draft, approval, scheduled publish and the user’s tab all work.
Round 8: Admin analytics
Dashboard with users by area, age and gender, total families, doctors with the most patients, and most-used medicines.
The madeBy view, a count of incomplete doctor and medicine records, and read-only doctor and medicine lists.
Q2 rollups for speed.
Done when: every number loads fast and matches the source data.
Round 9: Hardening and release
The Q3 query audit, and dropping unused indexes after checking pg_stat_user_indexes.
Load test the dose and missed-dose jobs.
A backup and restore check, a staged rollout, and the Play Store exact-alarm policy check.

