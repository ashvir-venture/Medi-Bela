-- Round 18 (owner, 2026-11-17; client point 17): consent, required at sign-up,
-- to the use of health data without name or phone to improve the service.
-- Additive; older accounts stay NULL.

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "researchConsentAt" TIMESTAMP(3);

