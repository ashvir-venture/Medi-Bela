# Backup and restore (Neon)

## What protects the data

- **Neon point-in-time restore (history retention).** Neon keeps the
  database's change history for the plan's retention window (check the
  project's *History retention* setting; raise it if the plan allows). Any
  moment inside that window can be restored as a new branch.
- **Logical dumps** (`pg_dump`) you take yourself, kept outside Neon. Do one
  before every schema change and weekly.

## Restore to a moment (Neon branch)

Use this after a bad deploy, a wrong bulk change or deleted data.

1. Neon → Branches → *Create branch* → *From a point in time* → pick a time
   just before the problem.
2. Check the new branch in the SQL editor (e.g. the rows you lost exist).
3. Either point Render's `DATABASE_URL` at the new branch and redeploy, or
   copy the needed rows back by hand. Don't overwrite the main branch until
   you have checked the restored one.

## Logical dump and restore

```bash
# Dump (custom format, no Neon-specific roles)
pg_dump "$NEON_DIRECT_URL" -Fc --no-owner --no-privileges -f medibela-$(date +%F).dump

# Restore into an EMPTY database (a new Neon branch/database, or local Postgres)
pg_restore -d "$TARGET_URL" --no-owner --no-privileges --exit-on-error medibela-YYYY-MM-DD.dump
```

Use the direct (non-pooled) connection string for both. `pg_dump` must be
the same major version as the server or newer.

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

The Neon point-in-time restore itself has to be tried in the Neon console
(create a branch from 10 minutes ago and open it); do that once after the
deploy.
