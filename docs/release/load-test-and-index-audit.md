# Load test and index audit (Round 9)

Run 2026-10-29 on a disposable local Postgres 18 (laptop), with
`backend/scripts/load-test.ts` (synthetic data, the real Nest services, jobs
called directly, push disabled). Rerun any time:

```bash
cd backend
LOAD_TEST_DATABASE_URL=postgresql://postgres@localhost:<port>/<db> npx ts-node scripts/load-test.ts --patients 1000 --out report.md
```

The target database needs every migration plus the pending SQL; the script
truncates it and refuses non-localhost URLs.

Data per patient: 1 confirmed prescription (1-3 medicines, 1-3 doses a day,
everyone has an 08:00 dose) plus 1 older one, 30 days of dose history, 13
days ahead, 20 inbox rows; 3 in 4 patients in a family of three. The peak is
simulated as everyone's 08:00 dose: the missed-dose job is run as of 08:35
(backstop time), then 85% are marked taken and it is run as of 09:05 (missed
+ family alert).

## Results

| | 1,000 patients | 10,000 | 20,000 |
|---|---|---|---|
| routines / doses / DB size | 2,018 / 174k / 64 MB | 20,014 / 1.7M / 531 MB | 40,010 / 3.4M / 1.0 GB |
| **rolling doses**: hourly runs needed to extend one day (200 routines a run, 24 runs a day) | 11 | **101** | **201** |
| **backstop pushes at 08:35** | **151 of 1,000** | **200 of 10,000** | **200 of 20,000** |
| missed + family alerts at 09:05: one-minute runs needed | 2 | 15 | 30 |
| scheduled notice to everyone (inbox rows created) | 1.0 s (1,218) | n/a (script bug, fixed) | 21.5 s (24,217) |
| today's doses, p95 | 2.8 ms | 8.0 ms | 7.3 ms |
| sync changes since yesterday, p95 | 12 ms | 9.5 ms | 14 ms |
| inbox first page / notices / family status, p95 | 1.4 / 7.3 / 4.7 ms | 3.4 / 4.7 / 7.0 ms | 3.4 / 7.5 / 6.2 ms |
| admin dashboard (cold) | 253 ms | 190 ms | 257 ms |
| admin analytics (uncached / cached) | 48 / 0.2 ms | 71 / 0.2 ms | 134 / 0.1 ms |
| prescription queue, first page | 5 ms | 5 ms | 3 ms |

### Findings

1. **Backstop pushes stop at 200 a minute and never reach the rest (bug, all
   sizes).** `sendBackstops` takes the first 200 pending doses in the window,
   ordered by time; once those have their push, the same 200 come back every
   minute (the unique key skips them) and everyone after them never gets the
   backstop. With 1,000 patients, 849 got none.
2. **The rolling-dose job falls behind above about 2,400 patients (bug at
   scale).** It extends 200 routines an hour (4,800 a day) and every routine
   needs one extension a day (about 2 routines per patient here). Past that, the 14-day horizon shrinks by up to a
   day per day for the routines it can't reach; after about two weeks those
   routines have no future doses, so their reminders stop. 10,000 patients
   need 101 runs a day, 20,000 need 201.
3. **Family alerts lag at the peak.** 200 missed doses a minute: at 20,000
   patients the last family alert of the 08:00 peak goes out about 30 minutes
   late (10,000: 15 minutes). Not wrong, but late.
4. **A notice to everyone creates one inbox row per user in one go**: 21.5 s at
   20,000 users inside the every-minute job. Acceptable now; worth batching
   past ~50,000 users.
5. Reads are fast at every size (all under 15 ms per user; staff pages under
   0.3 s). No query needs a new index.

### Fixed (2026-10-30)

1-3 are fixed: each job now keeps taking batches within one run (keyset
cursor) until it is done or its time budget is used (rolling doses 10 minutes,
missed-dose job 45 seconds; the next run continues), and the backstop query
selects whole (patient, time) groups that don't have their push yet. Tests
that failed before the fix: `rolling-dose.int.spec` (210 routines in one run;
finished courses no longer block routines behind them) and
`missed-dose-alert.int.spec` (211 backstops with all dose ids; 250 missed
doses in one run).

| after the fix | 1,000 patients | 20,000 patients |
|---|---|---|
| rolling doses: runs needed for a day | 1 (15 s) | 1 (110 s) |
| backstops at 08:35 | 1,000 of 1,000 in 1 run | 20,000 of 20,000 in 2 one-minute runs |
| missed + family alerts at 09:05 | 1 run (291 missed, 422 alerts) | 3 one-minute runs (5,942 missed, 8,934 alerts) |

The 20,000 run after the fix was on a busier laptop (its reads were 2-3x
slower than the first runs, e.g. today's doses p95 16 ms, admin dashboard
0.5 s; a notice to everyone took 110 s), so compare job runs, not
milliseconds, across the two tables.

## Index audit

Measured with `pg_stat_user_indexes` during the 10,000-patient run (counters
reset first). Unique and primary-key indexes enforce rules and are not
candidates.

**Used by the jobs and reads:** medicine_doses (userId, scheduledAt),
(routineId, scheduledAt), (status, scheduledAt); medicine_routines (userId,
active); notifications (pushStatus, createdAt), (userId, createdAt), (userId,
isRead); users (role). Keep.

**Not scanned in the test, but used by flows the test doesn't exercise** (keep):
prescriptions (userId, status) for "my prescriptions", (status, createdAt) for
the queue, (doctorId) for analytics and doctor pages; prescription_medicines
(prescriptionId, revision) and (medicineId); the prefix-search indexes from SQL
004 (catalog autosuggest); family_invitations, health_*, device_tokens,
assistant_conversations, audit_logs and notice indexes (their features weren't
in the test).

**Drop candidates (confirm on Neon first):**

| index | why it looks redundant |
|---|---|
| `doctors_name_idx` (plain btree on name) | Search uses `doctors_name_prefix_idx` (lower(name) text_pattern_ops); lists sort by createdAt. |
| ~~`medicines_genericName_idx`~~ | Dropped by pending SQL 007 (generic names moved to `medicine_generics`). |

It is tiny today, so there is no hurry.

### Checking on Neon after a few weeks of real use

```sql
SELECT s.relname AS table, s.indexrelname AS index, s.idx_scan AS scans,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE NOT i.indisunique AND NOT i.indisprimary
ORDER BY s.idx_scan, pg_relation_size(s.indexrelid) DESC;
```

An index with 0 scans after weeks of use, that isn't in the "keep" lists
above, can go: put the `DROP INDEX` in the next pending SQL file and remove
its `@@index` from `schema.prisma` in the same change.

## Not covered

- HTTP layer under concurrency (the test calls services directly; the rate
  limiter and Nest overhead aren't in these numbers). Neon's network latency
  (a few ms per query from Render) adds to every read.
- FCM delivery (push disabled in the test).
- Neon's compute size: these timings are from a laptop; a small Neon compute
  may be 2-3x slower.
