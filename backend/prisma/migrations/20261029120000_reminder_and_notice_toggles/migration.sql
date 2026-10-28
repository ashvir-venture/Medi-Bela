-- Round 3: separate medicine-reminder and notice switches (default on).
-- AlterTable
ALTER TABLE "users" ADD COLUMN     "medicineRemindersEnabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "noticesEnabled" BOOLEAN NOT NULL DEFAULT true;
