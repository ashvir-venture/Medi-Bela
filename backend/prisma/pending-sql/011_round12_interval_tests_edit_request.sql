-- Round 12: medicine form and "every N days" on medicine lines and routines;
-- the patient's "Request edit" note; test date / time / meal timing / note on
-- a prescription's tests; test reminders as health reminders (testId set,
-- new status MISSED, caregiver alert time). Additive only: existing lines and
-- routines get intervalDays = 1 (every day), as before.

-- AlterEnum
ALTER TYPE "HealthReminderStatus" ADD VALUE 'MISSED';

-- AlterTable
ALTER TABLE "prescriptions" ADD COLUMN     "editRequestNote" TEXT,
ADD COLUMN     "editRequestedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "prescription_medicines" ADD COLUMN     "formId" INTEGER,
ADD COLUMN     "intervalDays" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "medicine_routines" ADD COLUMN     "formId" INTEGER,
ADD COLUMN     "intervalDays" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "health_reminders" ADD COLUMN     "caregiverAlertedAt" TIMESTAMP(3),
ADD COLUMN     "mealTimingId" INTEGER,
ADD COLUMN     "prescriptionId" UUID,
ADD COLUMN     "testId" UUID;

-- AlterTable
ALTER TABLE "prescription_tests" ADD COLUMN     "mealTimingId" INTEGER,
ADD COLUMN     "note" TEXT,
ADD COLUMN     "scheduledDate" DATE,
ADD COLUMN     "time" TEXT;

-- CreateIndex
CREATE INDEX "health_reminders_status_scheduledAt_idx" ON "health_reminders"("status", "scheduledAt");

-- AddForeignKey
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_formId_fkey" FOREIGN KEY ("formId") REFERENCES "medicine_forms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_formId_fkey" FOREIGN KEY ("formId") REFERENCES "medicine_forms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_reminders" ADD CONSTRAINT "health_reminders_prescriptionId_fkey" FOREIGN KEY ("prescriptionId") REFERENCES "prescriptions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_reminders" ADD CONSTRAINT "health_reminders_testId_fkey" FOREIGN KEY ("testId") REFERENCES "diagnostic_tests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_reminders" ADD CONSTRAINT "health_reminders_mealTimingId_fkey" FOREIGN KEY ("mealTimingId") REFERENCES "meal_timings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescription_tests" ADD CONSTRAINT "prescription_tests_mealTimingId_fkey" FOREIGN KEY ("mealTimingId") REFERENCES "meal_timings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- Not expressible in schema.prisma.
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_intervalDays_check" CHECK ("intervalDays" BETWEEN 1 AND 90);
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_intervalDays_check" CHECK ("intervalDays" BETWEEN 1 AND 90);
