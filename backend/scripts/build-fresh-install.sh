#!/usr/bin/env bash
# Builds prisma/fresh-install.sql: every Prisma migration (with Prisma's
# _prisma_migrations rows), phase4a_extra.sql and every pending-sql file.
# Run from backend/ after adding a pending-sql file: bash scripts/build-fresh-install.sh
set -euo pipefail
B="${1:-.}"   # backend folder
OUT="$B/prisma/fresh-install.sql"
{
cat <<'HDR'
-- Medi-Bela 0.1.0: full schema + reference data for an EMPTY database.
-- Generated from prisma/migrations/*, migrations_phase4a/phase4a_extra.sql
-- and every prisma/pending-sql file, in the order of docs/release/deploy-runbook.md.
-- Do not edit by hand: rebuild with `bash scripts/build-fresh-install.sh`.
-- Run once on a new, empty Neon database. If any statement fails, drop the
-- database, create it again and re-run; do not run it on a database with data.
-- Afterwards: SELECT count(*) FROM divisions;  -- 8
--             SELECT count(*) FROM districts;  -- 64
-- Then seed the staff accounts (runbook step 3).

-- Prisma's migration history, so `prisma migrate status` sees every
-- migration as applied.
CREATE TABLE IF NOT EXISTS "_prisma_migrations" (
    "id"                  VARCHAR(36) PRIMARY KEY NOT NULL,
    "checksum"            VARCHAR(64) NOT NULL,
    "finished_at"         TIMESTAMPTZ,
    "migration_name"      VARCHAR(255) NOT NULL,
    "logs"                TEXT,
    "rolled_back_at"      TIMESTAMPTZ,
    "started_at"          TIMESTAMPTZ NOT NULL DEFAULT now(),
    "applied_steps_count" INTEGER NOT NULL DEFAULT 0
);
HDR
for d in "$B"/prisma/migrations/*/; do
  name=$(basename "$d")
  printf '\n-- ===== migration %s =====\n' "$name"
  cat "$d/migration.sql"
  sum=$(sha256sum "$d/migration.sql" | cut -d' ' -f1)
  printf '\nINSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '\''%s'\'', now(), '\''%s'\'', 1);\n' "$sum" "$name"
done
for f in "$B"/migrations_phase4a/phase4a_extra.sql "$B"/prisma/pending-sql/0*.sql; do
  printf '\n-- ===== %s =====\n' "${f#$B/}"
  cat "$f"
  printf '\n'
done
} > "$OUT"
echo "wrote $OUT ($(wc -l < "$OUT") lines)"
