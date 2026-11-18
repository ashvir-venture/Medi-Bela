# Backup and restore (Supabase)

Since 2026-11-18 the database is Supabase (Postgres 17, region
ap-southeast-1). Neon was used before; its old project is an archive only.

## What protects the data

- **Supabase backups.** Daily backups, and point-in-time recovery (PITR) as
  an add-on, depend on the project's plan (Pro and up). Check Project →
  Database → Backups to see what this project has. On the free plan there is
  no backup you can restore from the dashboard, so the dumps below are the
  only copy.
- **Logical dumps** (`pg_dump`) you take yourself, kept outside Supabase. Do
  one before every schema change and weekly.

## Restore from a Supabase backup

Use this after a bad deploy, a wrong bulk change or deleted data, when the
plan includes backups.

1. Project → Database → Backups → pick a daily backup (or, with PITR, a
   moment just before the problem) → Restore.
2. A restore replaces the project's database and takes it offline for a few
   minutes; turn on `MAINTENANCE_MODE=true` on Render first, back to `false`
   after the check.
3. Check the rows you lost exist (SQL editor), then the drift check below.

If you only need a few rows back, restore a `pg_dump` into a separate
database instead and copy them across by hand.

## Logical dump and restore

```bash
# Dump (custom format, no Supabase-specific roles or ownership)
pg_dump "$DB_URL" -Fc --no-owner --no-privileges --schema=public -f medibela-$(date +%F).dump

# Restore into an EMPTY database (a new Supabase project, or local Postgres)
pg_restore -d "$TARGET_URL" --no-owner --no-privileges --exit-on-error medibela-YYYY-MM-DD.dump
```

`DB_URL` is the **Session pooler** string (port 5432, `?sslmode=require`),
the same one the app uses; the direct `db.<ref>.supabase.co` host is IPv6
only. Do not use the Transaction pooler (port 6543) for `pg_dump`.
`--schema=public` keeps Supabase's own schemas (auth, storage, ...) out of
the dump: Medi-Bela only uses `public`. `pg_dump` must be the same major
version as the server (17) or newer.

Check after restoring:

1. Row counts match, table by table:
   ```sql
   SELECT table_name,
     (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from %I', table_name), false, true, '')))[1]::text::int AS n
   FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY 1;
   ```
2. Same number of indexes and constraints:
   `SELECT count(*) FROM pg_indexes WHERE schemaname = 'public';`
3. `npx prisma migrate diff --from-url "$SOURCE_URL" --to-url "$TARGET_URL" --script`
   prints an empty migration.

The dump holds patient data: keep it encrypted (e.g. an encrypted disk or
password-protected archive), never in the repository or a shared drive.

## Rehearsal (2026-10-29, local disposable Postgres 18)

| | small test database | load-test database (20,000 patients) |
|---|---|---|
| tables | 34 | 34 |
| rows | 652 | 4,156,317 (1.0 GB) |
| dump / restore time | 0.6 s / 0.7 s | 28 s / 44 s (`pg_restore -j 4`), 191 MB dump |
| row counts after restore | identical | identical |
| indexes / constraints | 92 / 270 both sides | 91 / 270 both sides |
| `prisma migrate diff` source → restored | empty | empty |

Not tried yet: a `pg_dump` of the Supabase database itself, and (if the plan
has it) a dashboard restore. Do a dump once now and keep it.
