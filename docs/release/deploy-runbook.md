# Deploy runbook: fresh Neon database + Render redeploy

For the 0.1.0 release. Render runs a pre-Round-1 build today; this replaces it
and starts the database from empty (there are no real users, and a clean start
avoids converting old test data).

Rehearsed on a disposable local Postgres (2026-10-29): every step below in
this order, then `prisma migrate diff` against `schema.prisma` showed no
differences.

## 0. Before you start

- Have the Neon project open, the Render service's Environment page open, and
  a terminal in `backend/` with `npm install` done.
- Pick a quiet time: the API will be down between step 3 and step 6 (a few
  minutes). The app keeps working offline and syncs afterwards.
- Keep the current Render env values somewhere safe (Render → Environment →
  copy), in case of rollback.

## 1. Create the new database (Neon)

1. In Neon, create a new branch or a new database, e.g. `medibela_v010`.
   Keep the old one untouched until step 8; it is the rollback.
2. Copy its connection string. Use the **direct** (non-pooled) URL for the
   steps below; the pooled one is fine for the running app.

## 2. Build the schema

In `backend/`, with `NEON_URL` set to the direct connection string.

Shortest way: one script with everything below (migrations, Prisma's
migration history, phase4a_extra and every pending file):

```bash
psql "$NEON_URL" -v ON_ERROR_STOP=1 -f prisma/fresh-install.sql
```

Or step by step:

```bash
DATABASE_URL="$NEON_URL" npx prisma migrate deploy
```

Then, in order, in the Neon SQL editor (or `psql "$NEON_URL" -f <file>`):

1. `migrations_phase4a/phase4a_extra.sql` (one pending invitation per family
   and phone, phone format, missed-dose backlog guard; safe to re-run)
2. `prisma/pending-sql/001_round3_reminder_and_notice_toggles.sql`
3. `prisma/pending-sql/002_round4_schema.sql`
4. `prisma/pending-sql/003_round4_reference_data.sql` (dropdown data)
5. `prisma/pending-sql/004_round5_search_indexes.sql`
6. `prisma/pending-sql/005_round6_caregiver.sql`
7. `prisma/pending-sql/006_round7_notice_review_note.sql`
8. `prisma/pending-sql/007_generic_names.sql`

Each must finish without an error before the next. On an empty database none
of them converts data.

Check: `SELECT count(*) FROM divisions;` returns 8, `SELECT count(*) FROM
districts;` returns 64.

## 3. Seed the staff accounts

Set your own values (never the defaults in `prisma/seed.ts`):

```bash
DATABASE_URL="$NEON_URL" SEED_ADMIN_PHONE="+8801XXXXXXXXX" SEED_ADMIN_PASSWORD="<strong password>" \
  SEED_PHARMACIST_PHONE="+8801XXXXXXXXX" SEED_PHARMACIST_PASSWORD="<strong password>" \
  npx ts-node prisma/seed.ts
```

The pharmacist pair is optional. Don't paste these passwords into chat,
tickets or the Render env.

## 4. Render environment

Set or check every variable in `backend/.env.example`. The ones that matter
for this release:

| Variable | Value |
|---|---|
| `DATABASE_URL` | the new Neon URL (pooled is fine) |
| `JWT_ACCESS_SECRET` | a new long random value (old app sessions end; users sign in again) |
| `PUSH_TOKEN_ENC_KEY` | `openssl rand -base64 32` (new database = no stored tokens to keep) |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | the service account (without it, push is off) |
| `CLOUDINARY_*` | unchanged |
| `LLM_API_BASE_URL` / `LLM_API_KEY` / `LLM_MODEL` | unchanged |
| `APP_UTC_OFFSET_MINUTES` | `360` |
| `DOSE_MISSED_GRACE_MINUTES` | `62`, or delete it (the code default is 62). An old value such as 120 would delay family alerts. |
| `MISSED_ALERT_MAX_AGE_MINUTES` | `360` |
| `MISSED_DOSE_JOB_ENABLED`, `ROLLING_DOSE_JOB_ENABLED`, `PUSH_DISPATCH_JOB_ENABLED`, `NOTICE_SCHEDULE_JOB_ENABLED` | `true` |
| `TRUST_PROXY` | `1` (Render sits behind a proxy; without it every public request shares one rate-limit bucket) |
| `RATE_LIMIT_ENABLED` | `true` |
| `CORS_ORIGINS` | the staff panel's URL |
| `SMS_API_URL` / `SMS_API_KEY` / `SMS_SENDER_ID` | your gateway (without them no reset codes are sent) |

Remove variables that no longer exist (e.g. an old refresh-token secret).
Do **not** set the `SEED_*` variables on Render.

Run a **single instance** (rate limits and background jobs are in-memory).

## 5. Deploy

Render service settings:

- Build command: `npm ci && npx prisma generate && npm run build`
- Start command: `npm run start:prod`
- Root directory: `backend`

Deploy the `main` branch (0.1.0).

## 6. Smoke test

1. `GET https://<api>/api/health` returns `{"status":"ok","service":"medi-bela backend"}`.
2. `GET https://<api>/api/lookups` returns divisions and districts.
3. Staff panel: sign in as the seeded admin, open Dashboard (analytics load),
   Doctors, Medicines, Notices. Sign in as the pharmacist: queue is empty.
4. App (release build pointing at the API): register a new account, upload a
   prescription photo, prepare it as the pharmacist, confirm it in the app,
   see today's doses and a reminder at the next scheduled time.
5. Render logs: no errors; within an hour, no "job failed" lines.

## 7. Cloudinary clean-up (by hand)

The pre-Round-2 test prescription images are **public** (`upload` type).
In the Cloudinary console → Media Library, filter by delivery type
*Upload* (public) in the prescriptions folder and delete them. New uploads
are `authenticated` and are not affected.

## 8. Afterwards

- Keep the old Neon branch for a week, then delete it.
- After a few weeks of real use, run the index check in
  `load-test-and-index-audit.md` against Neon before dropping anything.

## Rollback

Before step 8: point Render's `DATABASE_URL` back at the old database, restore
the saved env values, and redeploy the previous Render deploy (Render →
Deploys → the last good one → Redeploy). Nothing in steps 1-3 touches the old
database.
