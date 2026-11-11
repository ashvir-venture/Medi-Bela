-- Round 16 (owner, 2026-11-12): tag a medicine with one of the user's
-- conditions (conditions.code), shown on that condition's page. A personal
-- label only. Additive; existing routines stay untagged (NULL).

-- AlterTable
ALTER TABLE "medicine_routines" ADD COLUMN     "conditionCode" TEXT;

