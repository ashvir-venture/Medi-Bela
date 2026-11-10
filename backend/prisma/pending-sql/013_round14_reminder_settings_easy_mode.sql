-- Round 14: the user's own reminder timings (NULL = the .env default),
-- easy mode, and who marked a dose taken / whether it was late.
-- Additive only; existing doses keep takenById / takenLate NULL.

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "easyMode" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "familyAlertMinutes" INTEGER,
ADD COLUMN     "reminderLaterMinutes" INTEGER,
ADD COLUMN     "reminderRepeatMinutes" INTEGER,
ADD COLUMN     "reminderRings" INTEGER;

-- AlterTable
ALTER TABLE "medicine_doses" ADD COLUMN     "takenById" UUID,
ADD COLUMN     "takenLate" BOOLEAN;

-- AddForeignKey
ALTER TABLE "medicine_doses" ADD CONSTRAINT "medicine_doses_takenById_fkey" FOREIGN KEY ("takenById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Ranges the app offers (also checked by the API).
ALTER TABLE "users" ADD CONSTRAINT "users_reminderRepeatMinutes_check" CHECK ("reminderRepeatMinutes" IS NULL OR "reminderRepeatMinutes" BETWEEN 5 AND 60);
ALTER TABLE "users" ADD CONSTRAINT "users_reminderLaterMinutes_check" CHECK ("reminderLaterMinutes" IS NULL OR "reminderLaterMinutes" BETWEEN 5 AND 60);
ALTER TABLE "users" ADD CONSTRAINT "users_reminderRings_check" CHECK ("reminderRings" IS NULL OR "reminderRings" BETWEEN 1 AND 6);
ALTER TABLE "users" ADD CONSTRAINT "users_familyAlertMinutes_check" CHECK ("familyAlertMinutes" IS NULL OR "familyAlertMinutes" BETWEEN 5 AND 360);
