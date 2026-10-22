-- Phase 3A: prescription upload idempotency + structured fields needed for
-- deterministic routine generation. Purely additive — no existing columns
-- are altered or dropped, so no existing data is broken.

-- Prescription: idempotency key for offline upload retries
ALTER TABLE "prescriptions"
  ADD COLUMN "clientUploadId" TEXT;

CREATE UNIQUE INDEX "prescriptions_clientUploadId_key"
  ON "prescriptions" ("clientUploadId");

-- PrescriptionMedicine: structured fields consumed by routine generation.
-- Nullable because they only need to be populated (and validated) at the
-- point a prescription is completed, not while still being drafted.
ALTER TABLE "prescription_medicines"
  ADD COLUMN "timesPerDay" INTEGER,
  ADD COLUMN "scheduleTimes" TEXT,
  ADD COLUMN "durationDays" INTEGER,
  ADD COLUMN "startDate" TIMESTAMP(3);
