-- Keyset ("newest first", 20 per page) indexes for two staff lists:
-- the pharmacist's routine panel (GET /pharmacist/routines) and the admin
-- audit log (GET /admin/audit-logs). Index-only change, no data touched.
-- Safe to re-run.

-- CreateIndex
CREATE INDEX IF NOT EXISTS "medicine_routines_createdAt_id_idx" ON "medicine_routines"("createdAt", "id");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "audit_logs_createdAt_id_idx" ON "audit_logs"("createdAt", "id");
