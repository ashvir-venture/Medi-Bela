-- Round 18 (owner, 2026-11-17; client note points 1, 5, 6): Add medicine 2.0
-- and medicine box 2.0. Certain days (weekdays), only when needed (asNeeded
-- with maxPerDay / minGapHours, also on prescription lines), tablet colour /
-- shape, pack photo, note; box items with no reminder (a medicine at home or
-- a care supply), the unit a count is in (ml for a syrup), use per day and
-- when to remind. Additive (routineId becomes optional).

-- CreateEnum
CREATE TYPE "StockKind" AS ENUM ('MEDICINE', 'SUPPLY');

-- AlterTable
ALTER TABLE "prescription_medicines" ADD COLUMN     "asNeeded" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "maxPerDay" INTEGER,
ADD COLUMN     "minGapHours" INTEGER;

-- AlterTable
ALTER TABLE "medicine_routines" ADD COLUMN     "asNeeded" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "maxPerDay" INTEGER,
ADD COLUMN     "minGapHours" INTEGER,
ADD COLUMN     "note" TEXT,
ADD COLUMN     "packPhotoUrl" TEXT,
ADD COLUMN     "pillColor" TEXT,
ADD COLUMN     "pillShape" TEXT,
ADD COLUMN     "weekdays" TEXT;

-- AlterTable
ALTER TABLE "medicine_stocks" ADD COLUMN     "kind" "StockKind" NOT NULL DEFAULT 'MEDICINE',
ADD COLUMN     "name" TEXT,
ADD COLUMN     "perDay" DOUBLE PRECISION,
ADD COLUMN     "refillDays" INTEGER,
ADD COLUMN     "unit" TEXT,
ALTER COLUMN "routineId" DROP NOT NULL;


-- Limits the API also checks.
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_max_per_day" CHECK ("maxPerDay" IS NULL OR "maxPerDay" BETWEEN 1 AND 24);
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_min_gap_hours" CHECK ("minGapHours" IS NULL OR "minGapHours" BETWEEN 1 AND 48);
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_max_per_day" CHECK ("maxPerDay" IS NULL OR "maxPerDay" BETWEEN 1 AND 24);
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_min_gap_hours" CHECK ("minGapHours" IS NULL OR "minGapHours" BETWEEN 1 AND 48);
-- A box item without a reminder must have a name.
ALTER TABLE "medicine_stocks" ADD CONSTRAINT "medicine_stocks_named" CHECK ("routineId" IS NOT NULL OR "name" IS NOT NULL);
ALTER TABLE "medicine_stocks" ADD CONSTRAINT "medicine_stocks_per_day" CHECK ("perDay" IS NULL OR "perDay" > 0);
ALTER TABLE "medicine_stocks" ADD CONSTRAINT "medicine_stocks_refill_days" CHECK ("refillDays" IS NULL OR "refillDays" BETWEEN 1 AND 30);
