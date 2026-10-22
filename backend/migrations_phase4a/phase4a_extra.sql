-- Phase 4A: SQL Prisma's schema language cannot express. Run AFTER the
-- Prisma migration (prisma migrate dev --name phase4a). Safe to re-run.

-- 1. At most one PENDING invitation per (family, phone). Closes the
--    check-then-insert race when an owner double-submits an invite.
CREATE UNIQUE INDEX IF NOT EXISTS family_invitations_one_pending_per_phone
  ON family_invitations ("familyId", "invitedPhone")
  WHERE status = 'PENDING';

-- 2. One canonical phone format (+<digits>). Existing rows registered before
--    normalisation may lack the '+' (the old validator allowed that), which
--    would make them invisible to invitations. Aborts loudly (unique
--    violation) if two rows collapse to the same number — resolve by hand.
UPDATE users SET phone = '+' || regexp_replace(phone, '[^0-9]', '', 'g')
  WHERE phone !~ '^\+[0-9]+$';
UPDATE family_invitations SET "invitedPhone" = '+' || regexp_replace("invitedPhone", '[^0-9]', '', 'g')
  WHERE "invitedPhone" !~ '^\+[0-9]+$';

-- 3. Doses already MISSED before this release must not trigger a flood of
--    family alerts the first time the job runs.
UPDATE medicine_doses SET "familyAlertProcessedAt" = now()
  WHERE status = 'MISSED' AND "familyAlertProcessedAt" IS NULL;
