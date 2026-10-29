-- Round 5: prefix-search indexes for the pharmacist autosuggest
-- (CatalogService.searchDoctors / searchMedicines / searchTests), which query
-- `lower(column) LIKE 'text%'`. Prisma's schema can't express expression
-- indexes, so they live only here (like the Round 4 CHECK constraints).
-- text_pattern_ops lets LIKE 'prefix%' use the index under any collation.
-- No schema.prisma change this round. Safe to re-run.

CREATE INDEX IF NOT EXISTS "doctors_name_prefix_idx"
  ON "doctors" (lower("name") text_pattern_ops);

CREATE INDEX IF NOT EXISTS "medicines_brandName_prefix_idx"
  ON "medicines" (lower("brandName") text_pattern_ops);

CREATE INDEX IF NOT EXISTS "medicines_genericName_prefix_idx"
  ON "medicines" (lower("genericName") text_pattern_ops);

CREATE INDEX IF NOT EXISTS "diagnostic_tests_name_prefix_idx"
  ON "diagnostic_tests" (lower("name") text_pattern_ops);
