/**
 * Load test for the background jobs and the hottest reads, on synthetic data.
 *
 *   LOAD_TEST_DATABASE_URL=postgresql://postgres@localhost:55432/loadtest \
 *     npx ts-node scripts/load-test.ts --patients 1000 [--history-days 30] [--out report.md]
 *
 * WARNING: it TRUNCATES the target database. It refuses anything but a local
 * host (localhost / 127.0.0.1) and refuses the DATABASE_URL in .env.
 * The database must already have every migration plus the pending SQL applied.
 *
 * Scale is a parameter: the same script runs the 1,000-patient target and the
 * 10,000-20,000-patient check (--patients 20000).
 *
 * What it does:
 *   1. Generates data with set-based SQL: N patients (3 in 4 in a family of
 *      three), staff, doctors, catalog medicines, prescriptions with lines,
 *      routines (1-3 times a day) with doses for `history-days` back and 13 days
 *      ahead (one day short of the 14-day horizon, so the rolling job has a
 *      day of work, as it does every day at midnight), the last 3 hours of
 *      doses still PENDING (sweep, family alerts and backstops have work),
 *      inbox history and notices (two scheduled ones due now).
 *   2. Resets pg_stat counters, then times, through the real Nest services:
 *      each job until it has nothing left (runs needed = how far behind one
 *      scheduled run falls), and the hot reads for a sample of users.
 *   3. Reports timings and per-index scan counts (input for the index audit).
 */
import { NestFactory } from '@nestjs/core';
import { INestApplicationContext } from '@nestjs/common';
import { Role } from '@prisma/client';
import { writeFileSync } from 'fs';

// ---- arguments and safety ----------------------------------------------------

function arg(name: string, fallback?: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const PATIENTS = Number(arg('patients', '1000'));
const HISTORY_DAYS = Number(arg('history-days', '30'));
const OUT = arg('out');
const SAMPLE = 50;
// Prisma stores DateTime as UTC in timestamp-without-time-zone columns.
const NOW = `(now() AT TIME ZONE 'UTC')`;

const url = process.env.LOAD_TEST_DATABASE_URL;
if (!url) throw new Error('Set LOAD_TEST_DATABASE_URL to a disposable local database.');
if (!/@(localhost|127\.0\.0\.1)(:\d+)?\//.test(url)) {
  throw new Error('Refusing: LOAD_TEST_DATABASE_URL must point at localhost (the script truncates tables).');
}
try {
  process.loadEnvFile();
} catch {
  /* no .env */
}
if (process.env.DATABASE_URL && process.env.DATABASE_URL === url) {
  throw new Error('Refusing: LOAD_TEST_DATABASE_URL is the same as DATABASE_URL.');
}
if (!Number.isInteger(PATIENTS) || PATIENTS < 10 || PATIENTS > 50_000) throw new Error('--patients: 10..50000');

// The app reads these at start-up; jobs stay off (the script calls them itself)
// and push stays disabled (no FCM credentials), so nothing leaves the machine.
Object.assign(process.env, {
  DATABASE_URL: url,
  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || 'load-test-'.padEnd(40, 'x'),
  PUSH_TOKEN_ENC_KEY: Buffer.alloc(32, 7).toString('base64'),
  MISSED_DOSE_JOB_ENABLED: 'false',
  PUSH_DISPATCH_JOB_ENABLED: 'false',
  ROLLING_DOSE_JOB_ENABLED: 'false',
  NOTICE_SCHEDULE_JOB_ENABLED: 'false',
  RATE_LIMIT_ENABLED: 'false',
  // The code defaults, not a local .env's values.
  DOSE_MISSED_GRACE_MINUTES: '62',
  MISSED_ALERT_MAX_AGE_MINUTES: '360',
  FIREBASE_SERVICE_ACCOUNT_BASE64: '',
  FIREBASE_SERVICE_ACCOUNT_JSON: '',
  GOOGLE_APPLICATION_CREDENTIALS: '',
  LLM_API_BASE_URL: '',
  SMS_API_URL: '',
});

// Imported after the env is set (modules read it when loaded).
/* eslint-disable @typescript-eslint/no-require-imports */
const { AppModule } = require('../src/app.module');
const { PrismaService } = require('../src/prisma/prisma.service');
const { RollingDoseJob } = require('../src/medicine-schedule/rolling-dose.job');
const { MissedDoseAlertService } = require('../src/medicine-schedule/missed-dose-alert.service');
const { MedicineScheduleService } = require('../src/medicine-schedule/medicine-schedule.service');
const { NoticesService } = require('../src/notices/notices.service');
const { NotificationsService } = require('../src/notifications/notifications.service');
const { FamilyService } = require('../src/family/family.service');
const { PrescriptionsService } = require('../src/prescriptions/prescriptions.service');
const { AdminDashboardService } = require('../src/admin/admin-dashboard.service');
const { AdminAnalyticsService } = require('../src/admin/admin-analytics.service');
const { startOfAppDay } = require('../src/common/utils/time.util');
/* eslint-enable @typescript-eslint/no-require-imports */

// ---- data generation -----------------------------------------------------------

/** A Date as a literal for a UTC timestamp-without-time-zone column. */
const sqlTs = (d: Date) => d.toISOString().replace('T', ' ').replace('Z', '');

/** Today's 08:00 dose time (app timezone): every routine has one, so it is the busiest minute of the day. */
const morningSlot = (now: Date) => new Date((startOfAppDay(now) as Date).getTime() + 8 * 3_600_000);

async function generate(prisma: any, now: Date) {
  const today = startOfAppDay(now) as Date;
  const slot = morningSlot(now);
  const sql = (q: string) => prisma.$executeRawUnsafe(q);

  await sql(`TRUNCATE users, families, doctors, medicines, prescriptions, notices, audit_logs RESTART IDENTITY CASCADE`);

  // Staff: 1 admin, 3 pharmacists.
  await sql(`INSERT INTO users (id, phone, name, "passwordHash", role, "updatedAt")
    SELECT gen_random_uuid(), '+88017' || lpad(g::text, 8, '0'), 'Staff ' || g, 'x',
      (CASE WHEN g = 1 THEN 'ADMIN' ELSE 'PHARMACIST' END)::"Role", ${NOW}
    FROM generate_series(1, 4) g`);

  // Patients with address, gender and age spread over the lookup tables.
  await sql(`INSERT INTO users (id, phone, name, "passwordHash", role, "dateOfBirth", "genderId",
      "divisionId", "districtId", "upazilaId", "updatedAt")
    SELECT gen_random_uuid(), '+88019' || lpad(g::text, 8, '0'), 'Patient ' || g, 'x', 'USER',
      DATE '2026-01-01' - ((5 + (g * 7919) % 80) || ' years')::interval,
      (SELECT id FROM genders ORDER BY id LIMIT 1 OFFSET (g % 2)),
      u."divisionId", u."districtId", u.id, ${NOW} - ((g % 300) || ' days')::interval
    FROM generate_series(1, ${PATIENTS}) g
    JOIN LATERAL (SELECT up.id, d.id AS "districtId", d."divisionId"
      FROM upazilas up JOIN districts d ON d.id = up."districtId"
      ORDER BY up.id OFFSET ((g * 37) % (SELECT count(*) FROM upazilas)) LIMIT 1) u ON true`);

  // Families of three: patients 4k+1 (caregiver), 4k+2, 4k+3; every 4th patient has none.
  await sql(`CREATE TEMP TABLE lt_patients AS
    SELECT id, row_number() OVER (ORDER BY phone) AS n FROM users WHERE role = 'USER'`);
  await sql(`INSERT INTO families (id, name, "updatedAt")
    SELECT gen_random_uuid(), 'Family ' || k, ${NOW} FROM generate_series(0, ${Math.ceil(PATIENTS / 4)} - 1) k`);
  await sql(`CREATE TEMP TABLE lt_families AS SELECT id, row_number() OVER (ORDER BY name) - 1 AS k FROM families`);
  await sql(`INSERT INTO family_members (id, "familyId", "userId", role)
    SELECT gen_random_uuid(), f.id, p.id, (CASE WHEN p.n % 4 = 1 THEN 'CAREGIVER' ELSE 'MEMBER' END)::"FamilyRole"
    FROM lt_patients p JOIN lt_families f ON f.k = (p.n - 1) / 4
    WHERE p.n % 4 <> 0`);

  // Catalog.
  await sql(`INSERT INTO doctors (id, name, "specialtyId", phone, chamber, "createdById", "updatedAt")
    SELECT gen_random_uuid(), 'Dr. ' || g, (SELECT id FROM doctor_specialties ORDER BY id LIMIT 1 OFFSET (g % (SELECT count(*) FROM doctor_specialties))),
      CASE WHEN g % 3 <> 0 THEN '0171' || lpad(g::text, 7, '0') END, 'Chamber ' || g,
      (SELECT id FROM users WHERE role = 'PHARMACIST' ORDER BY phone LIMIT 1), ${NOW}
    FROM generate_series(1, ${Math.max(20, Math.ceil(PATIENTS / 20))}) g`);
  await sql(`INSERT INTO medicines (id, "brandName", "formId", "categoryId", manufacturer, "createdById", "updatedAt")
    SELECT gen_random_uuid(), 'Brand ' || g,
      (SELECT id FROM medicine_forms ORDER BY id LIMIT 1 OFFSET (g % (SELECT count(*) FROM medicine_forms))),
      (SELECT id FROM medicine_categories ORDER BY id LIMIT 1 OFFSET (g % (SELECT count(*) FROM medicine_categories))),
      CASE WHEN g % 5 <> 0 THEN 'Maker ' || (g % 40) END,
      (SELECT id FROM users WHERE role = 'PHARMACIST' ORDER BY phone LIMIT 1), ${NOW}
    FROM generate_series(1, 300) g`);
  await sql(`CREATE TEMP TABLE lt_doctors AS SELECT id, row_number() OVER (ORDER BY name) - 1 AS k FROM doctors`);
  await sql(`CREATE TEMP TABLE lt_medicines AS SELECT id, "brandName", row_number() OVER (ORDER BY "brandName") - 1 AS k FROM medicines`);

  // Prescriptions: one confirmed (ACTIVE) per patient, plus an older one in another state.
  await sql(`INSERT INTO prescriptions (id, "userId", "imageUrl", status, "doctorId", "uploadedById", "createdAt", "updatedAt")
    SELECT gen_random_uuid(), p.id, 'https://img.test/rx.jpg', 'ACTIVE', d.id, p.id,
      ${NOW} - (((p.n % 60) + ${HISTORY_DAYS}) || ' days')::interval, ${NOW}
    FROM lt_patients p JOIN lt_doctors d ON d.k = (p.n * 7) % (SELECT count(*) FROM lt_doctors)`);
  await sql(`INSERT INTO prescriptions (id, "userId", "imageUrl", status, "doctorId", "rejectionReason", "createdAt", "updatedAt")
    SELECT gen_random_uuid(), p.id, 'https://img.test/rx.jpg',
      (ARRAY['ENDED','PENDING','REJECTED','AWAITING_CONFIRMATION'])[1 + p.n % 4]::"PrescriptionStatus",
      CASE WHEN p.n % 4 IN (0, 3) THEN d.id END, CASE WHEN p.n % 4 = 2 THEN 'Unclear photo' END,
      ${NOW} - ((p.n % 120) || ' days')::interval, ${NOW}
    FROM lt_patients p JOIN lt_doctors d ON d.k = (p.n * 13) % (SELECT count(*) FROM lt_doctors)`);

  // 1-3 lines per prescription, 1-3 doses a day each.
  await sql(`INSERT INTO prescription_medicines (id, "prescriptionId", "medicineId", "medicineName", dosage, frequency,
      duration, "timesPerDay", "scheduleTimes", continuous, "updatedAt")
    SELECT gen_random_uuid(), rx.id, m.id, m."brandName", '1 tablet', 'daily', 'continuous', t.tpd,
      (ARRAY['["08:00"]','["08:00","20:00"]','["08:00","14:00","20:00"]'])[t.tpd], true, ${NOW}
    FROM (SELECT id, row_number() OVER (ORDER BY id) AS r FROM prescriptions) rx
    CROSS JOIN LATERAL generate_series(1, 1 + (rx.r % 3)::int) line
    JOIN lt_medicines m ON m.k = (rx.r * 31 + line * 17) % 300
    CROSS JOIN LATERAL (SELECT 1 + ((rx.r + line) % 3)::int AS tpd) t`);

  // Routines for the ACTIVE prescriptions' lines, generated one day short of the horizon.
  const generatedUntil = new Date(today.getTime() + 13 * 86_400_000).toISOString();
  const startDate = new Date(today.getTime() - HISTORY_DAYS * 86_400_000).toISOString();
  await sql(`INSERT INTO medicine_routines (id, "userId", "prescriptionMedicineId", "medicineName", dosage, frequency,
      "startDate", active, source, "scheduleTimes", "generatedUntil", "updatedAt")
    SELECT gen_random_uuid(), rx."userId", pm.id, pm."medicineName", pm.dosage, pm.frequency,
      '${startDate}', true, 'PRESCRIPTION', pm."scheduleTimes", '${generatedUntil}', ${NOW}
    FROM prescription_medicines pm JOIN prescriptions rx ON rx.id = pm."prescriptionId"
    WHERE rx.status = 'ACTIVE'`);

  // Doses: history (mostly taken) up to today's 08:00 dose, which is still pending, and 13 days ahead.
  await sql(`INSERT INTO medicine_doses (id, "routineId", "userId", "scheduledAt", status, "takenAt",
      "familyAlertProcessedAt", "updatedAt")
    SELECT gen_random_uuid(), r.id, r."userId", s.at,
      (CASE WHEN s.at >= TIMESTAMP '${sqlTs(slot)}' THEN 'PENDING'
            WHEN abs(hashtext(r.id::text || s.at::text)) % 100 < 85 THEN 'TAKEN' ELSE 'MISSED' END)::"DoseStatus",
      CASE WHEN s.at < TIMESTAMP '${sqlTs(slot)}' AND abs(hashtext(r.id::text || s.at::text)) % 100 < 85
           THEN s.at + interval '5 minutes' END,
      CASE WHEN s.at < TIMESTAMP '${sqlTs(slot)}' AND abs(hashtext(r.id::text || s.at::text)) % 100 >= 85
           THEN s.at + interval '62 minutes' END,
      ${NOW}
    FROM medicine_routines r
    CROSS JOIN LATERAL json_array_elements_text(r."scheduleTimes"::json) t(hhmm)
    CROSS JOIN LATERAL generate_series(-${HISTORY_DAYS}, 12) d
    -- today = the app-timezone midnight as a UTC instant; schedule times are app-local.
    CROSS JOIN LATERAL (SELECT TIMESTAMP '${sqlTs(today)}'
      + (d || ' days')::interval + t.hhmm::time AS at) s`);

  // Inbox history: 20 delivered notifications per patient.
  await sql(`INSERT INTO notifications (id, "userId", type, title, body, "relatedEntityId", "isRead", "pushStatus", "createdAt")
    SELECT gen_random_uuid(), p.id, 'SYSTEM', 'Update', 'Something changed', 'lt:' || g, g % 3 = 0, 'SENT',
      ${NOW} - (g || ' hours')::interval
    FROM lt_patients p CROSS JOIN generate_series(1, 20) g`);

  // Notices: 40 live (every 4th limited to one division), 2 scheduled and due now.
  await sql(`INSERT INTO notices (id, title, content, status, audience, "publishedAt", "startsAt", "createdAt", "updatedAt")
    SELECT gen_random_uuid(), 'Notice ' || g, 'Text', 'PUBLISHED', 'ALL',
      CASE WHEN g <= 40 THEN ${NOW} - (g || ' days')::interval END,
      CASE WHEN g > 40 THEN ${NOW} - interval '1 minute' END, ${NOW}, ${NOW}
    FROM generate_series(1, 42) g`);
  await sql(`INSERT INTO notice_divisions ("noticeId", "divisionId")
    SELECT n.id, (SELECT id FROM divisions ORDER BY id LIMIT 1)
    FROM (SELECT id, row_number() OVER (ORDER BY title) AS r FROM notices) n WHERE n.r % 4 = 0`);

  await sql('ANALYZE');
}

// ---- measuring -------------------------------------------------------------------

async function timed<T>(fn: () => Promise<T>): Promise<[T, number]> {
  const t = process.hrtime.bigint();
  const value = await fn();
  return [value, Number(process.hrtime.bigint() - t) / 1e6];
}

function pct(values: number[], p: number) {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))];
}

const ms = (n: number) => `${n.toFixed(n < 10 ? 1 : 0)} ms`;

async function main() {
  const now = new Date();
  const lines: string[] = [];
  const log = (s = '') => {
    console.log(s);
    lines.push(s);
  };

  const app: INestApplicationContext = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn'],
  });
  // Services come from require() (loaded after the env is set), so they're untyped here.
  const get = (token: unknown): any => app.get(token as any);
  const prisma = get(PrismaService);

  log(`# Load test: ${PATIENTS.toLocaleString()} patients, ${HISTORY_DAYS} days of history`);
  log(`Run ${now.toISOString()}`);
  log();

  const [, genMs] = await timed(() => generate(prisma, now));
  const counts = await prisma.$queryRawUnsafe(`SELECT
      (SELECT count(*) FROM users)::int AS users, (SELECT count(*) FROM families)::int AS families,
      (SELECT count(*) FROM prescriptions)::int AS prescriptions, (SELECT count(*) FROM medicine_routines)::int AS routines,
      (SELECT count(*) FROM medicine_doses)::int AS doses, (SELECT count(*) FROM notifications)::int AS notifications,
      (SELECT count(*) FROM medicine_doses WHERE status = 'PENDING' AND "scheduledAt" < ${NOW})::int AS overdue,
      pg_size_pretty(pg_database_size(current_database())) AS size`);
  log(`## Data (generated in ${(genMs / 1000).toFixed(1)} s)`);
  log('| users | families | prescriptions | routines | doses | notifications | pending past doses | DB size |');
  log('|---|---|---|---|---|---|---|---|');
  const c = counts[0];
  log(`| ${c.users} | ${c.families} | ${c.prescriptions} | ${c.routines} | ${c.doses} | ${c.notifications} | ${c.overdue} | ${c.size} |`);
  log();

  await prisma.$executeRawUnsafe('SELECT pg_stat_reset()');

  // ---- jobs: run each until it has nothing left -------------------------------
  log('## Jobs');
  log('Each job is run until it has no work left. "Runs" is how many scheduled runs that takes; a job that needs');
  log('more runs than fit in its interval falls behind.');
  log();
  log('| job | runs | total | slowest run | work done |');
  log('|---|---|---|---|---|');

  const rolling = get(RollingDoseJob);
  {
    let runs = 0, total = 0, slowest = 0, created = 0;
    for (;;) {
      const [n, t] = await timed<number>(() => rolling.run(now));
      runs++; total += t; slowest = Math.max(slowest, t); created += n;
      if (n === 0 || runs > 500) break;
    }
    log(`| rolling doses (hourly) | ${runs - 1} | ${ms(total)} | ${ms(slowest)} | ${created} doses for ${c.routines} routines |`);
  }

  // The busiest minute: every patient's 08:00 dose. The job is run as of 08:35
  // (backstop time) and, after 85% are marked taken, as of 09:05 (missed + family alert).
  const missed = get(MissedDoseAlertService);
  const slot = morningSlot(now);
  const drain = async (label: string, at: Date) => {
    let runs = 0, total = 0, slowest = 0, swept = 0, alerted = 0, backstops = 0;
    for (;;) {
      const [r, t] = await timed<{ swept: number; alerted: number; backstops: number }>(() => missed.run(at));
      runs++; total += t; slowest = Math.max(slowest, t);
      swept += r.swept; alerted += r.alerted; backstops += r.backstops;
      if ((r.swept === 0 && r.alerted === 0 && r.backstops === 0) || runs > 200) break;
    }
    const work = `${swept} marked missed, ${alerted} family alerts, ${backstops} backstops`;
    log(`| missed dose (every minute), ${label} | ${runs > 200 ? '200+ (stopped)' : runs - 1} | ${ms(total)} | ${ms(slowest)} | ${work} |`);
  };
  const groups: any[] = await prisma.$queryRawUnsafe(`SELECT count(DISTINCT "userId")::int AS n FROM medicine_doses
    WHERE "scheduledAt" = TIMESTAMP '${sqlTs(slot)}' AND status = 'PENDING'`);
  await drain('08:35', new Date(slot.getTime() + 35 * 60_000));
  const backstopsSent: any[] = await prisma.$queryRawUnsafe(`SELECT count(*)::int AS n FROM notifications
    WHERE "relatedEntityId" = 'backstop:${slot.toISOString()}'`);
  await prisma.$executeRawUnsafe(`UPDATE medicine_doses SET status = 'TAKEN', "takenAt" = "scheduledAt" + interval '10 minutes'
    WHERE "scheduledAt" = TIMESTAMP '${sqlTs(slot)}' AND abs(hashtext(id::text)) % 100 < 85`);
  const stillPending: any[] = await prisma.$queryRawUnsafe(`SELECT count(*)::int AS n FROM medicine_doses
    WHERE "scheduledAt" = TIMESTAMP '${sqlTs(slot)}' AND status = 'PENDING'`);
  await drain('09:05', new Date(slot.getTime() + 65 * 60_000));
  log();
  log(`08:00 doses: ${groups[0].n} patients due. Backstops sent at 08:35: ${backstopsSent[0].n} of ${groups[0].n}.`);
  log(`${stillPending[0].n} doses still untaken at 09:05 (15%), so that many become missed and alert their family.`);
  log();

  const notices = get(NoticesService);
  {
    const [n, t] = await timed(() => notices.goLive(new Date()));
    const pushed = await prisma.$queryRawUnsafe(`SELECT count(*)::int AS n FROM notifications WHERE type = 'NOTICE'`);
    log(`Scheduled notices: ${n} went live in ${ms(t)}, creating ${pushed[0].n} inbox rows (one per eligible user).`);
    log();
  }

  // ---- hot reads -----------------------------------------------------------------
  const sample: { id: string }[] = await prisma.$queryRawUnsafe(
    `SELECT id FROM users WHERE role = 'USER' ORDER BY md5(id::text) LIMIT ${SAMPLE}`,
  );
  const caregivers: { id: string }[] = await prisma.$queryRawUnsafe(
    `SELECT "userId" AS id FROM family_members WHERE role = 'CAREGIVER' ORDER BY md5("userId"::text) LIMIT ${SAMPLE}`,
  );
  const schedule = get(MedicineScheduleService);
  const inbox = get(NotificationsService);
  const family = get(FamilyService);
  const since = new Date(now.getTime() - 86_400_000);

  log(`## Reads (${SAMPLE} users each, after the jobs ran)`);
  log('| read | p50 | p95 | max |');
  log('|---|---|---|---|');
  const perUser = async (label: string, users: { id: string }[], fn: (id: string) => Promise<unknown>) => {
    const times: number[] = [];
    for (const u of users) times.push((await timed(() => fn(u.id)))[1]);
    log(`| ${label} | ${ms(pct(times, 50))} | ${ms(pct(times, 95))} | ${ms(Math.max(...times))} |`);
  };
  await perUser("today's doses", sample, (id) => schedule.getTodaysSchedule(id));
  await perUser('sync changes since yesterday', sample, (id) => schedule.getChangesSince(id, since));
  await perUser('active routines', sample, (id) => schedule.getActiveRoutines(id));
  await perUser('inbox, first page', sample, (id) => inbox.list(id, 10));
  await perUser('notices list', sample, (id) => notices.listVisibleTo(id, Role.USER));
  await perUser('family status (caregiver)', caregivers, (id) => family.getMembersStatusSummary(id));
  log();

  log('## Staff reads (single call, cold)');
  log('| read | time |');
  log('|---|---|');
  const once = async (label: string, fn: () => Promise<unknown>) => log(`| ${label} | ${ms((await timed(fn))[1])} |`);
  await once('admin dashboard', () => get(AdminDashboardService).getDashboard(now));
  await once('admin analytics overview (uncached)', () => get(AdminAnalyticsService).getOverview(now));
  await once('admin analytics overview (cached)', () => get(AdminAnalyticsService).getOverview(now));
  await once('top doctors, page 1', () => get(AdminAnalyticsService).listTopDoctors());
  await once('prescription queue, first page', () => get(PrescriptionsService).listQueue());
  log();

  // ---- index usage during the run ----------------------------------------------------
  const idx: any[] = await prisma.$queryRawUnsafe(`SELECT s.relname AS table, s.indexrelname AS index, s.idx_scan::int AS scans,
      pg_size_pretty(pg_relation_size(s.indexrelid)) AS size, i.indisunique AS unique, i.indisprimary AS primary
    FROM pg_stat_user_indexes s JOIN pg_index i ON i.indexrelid = s.indexrelid
    ORDER BY s.idx_scan ASC, pg_relation_size(s.indexrelid) DESC`);
  log('## Index scans during the jobs and reads above');
  log('Unused here is not proof of unused in production (writes, admin pages and app flows not exercised here also');
  log('use indexes); unique and primary-key indexes enforce rules and are never drop candidates.');
  log();
  log('| table | index | scans | size | kind |');
  log('|---|---|---|---|---|');
  for (const r of idx) {
    log(`| ${r.table} | ${r.index} | ${r.scans} | ${r.size} | ${r.primary ? 'primary key' : r.unique ? 'unique' : ''} |`);
  }

  if (OUT) writeFileSync(OUT, lines.join('\n') + '\n');
  await app.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
