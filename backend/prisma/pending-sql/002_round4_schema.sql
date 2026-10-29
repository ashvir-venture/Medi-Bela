-- Round 4: data foundation (lookup tables, doctors, medicines, tests, structured
-- prescription lines, routine columns, notice fields, audit log). Run after 001.
-- CreateEnum
CREATE TYPE "RoutineSource" AS ENUM ('PRESCRIPTION', 'SELF_ADDED');

-- AlterEnum
BEGIN;
CREATE TYPE "PrescriptionStatus_new" AS ENUM ('PENDING', 'REJECTED', 'AWAITING_CONFIRMATION', 'ACTIVE', 'ENDED');
ALTER TABLE "prescriptions" ALTER COLUMN "status" DROP DEFAULT;
-- Existing COMPLETED prescriptions become ACTIVE, so their reminders keep running.
ALTER TABLE "prescriptions" ALTER COLUMN "status" TYPE "PrescriptionStatus_new" USING (
  CASE WHEN "status"::text = 'COMPLETED' THEN 'ACTIVE' ELSE "status"::text END
)::"PrescriptionStatus_new";
ALTER TYPE "PrescriptionStatus" RENAME TO "PrescriptionStatus_old";
ALTER TYPE "PrescriptionStatus_new" RENAME TO "PrescriptionStatus";
DROP TYPE "PrescriptionStatus_old";
ALTER TABLE "prescriptions" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
ALTER TYPE "NoticeStatus" ADD VALUE 'PENDING_APPROVAL';

-- DropIndex
DROP INDEX "prescriptions_status_idx";

-- DropIndex
DROP INDEX "prescription_medicines_prescriptionId_idx";

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "dateOfBirth" DATE,
ADD COLUMN     "districtId" INTEGER,
ADD COLUMN     "divisionId" INTEGER,
ADD COLUMN     "genderId" INTEGER,
ADD COLUMN     "upazilaId" INTEGER;

-- AlterTable
ALTER TABLE "prescriptions" ADD COLUMN     "currentRevision" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "diagnosis" TEXT,
ADD COLUMN     "doctorId" UUID,
ADD COLUMN     "nextVisitDate" DATE,
ADD COLUMN     "pendingRevision" INTEGER,
ADD COLUMN     "previousPrescriptionId" UUID,
ADD COLUMN     "visitDate" DATE;

-- AlterTable
ALTER TABLE "prescription_medicines" ADD COLUMN     "continuous" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "doseAmount" TEXT,
ADD COLUMN     "mealTimingId" INTEGER,
ADD COLUMN     "medicineId" UUID,
ADD COLUMN     "revision" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "strength" TEXT;

-- AlterTable
ALTER TABLE "medicine_routines" ADD COLUMN     "doseAmount" TEXT,
ADD COLUMN     "generatedUntil" TIMESTAMP(3),
ADD COLUMN     "lastEditedAt" TIMESTAMP(3),
ADD COLUMN     "lastEditedById" UUID,
ADD COLUMN     "mealTimingId" INTEGER,
ADD COLUMN     "scheduleTimes" TEXT,
ADD COLUMN     "source" "RoutineSource" NOT NULL DEFAULT 'PRESCRIPTION',
ADD COLUMN     "strength" TEXT;

-- AlterTable
ALTER TABLE "notices" ADD COLUMN     "approvedAt" TIMESTAMP(3),
ADD COLUMN     "approvedById" UUID,
ADD COLUMN     "source" TEXT,
ADD COLUMN     "sourceUrl" TEXT,
ADD COLUMN     "startsAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "genders" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "genders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "divisions" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "divisions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "districts" (
    "id" SERIAL NOT NULL,
    "divisionId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "districts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "upazilas" (
    "id" SERIAL NOT NULL,
    "districtId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "upazilas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "doctor_specialties" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "doctor_specialties_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicine_forms" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "medicine_forms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicine_categories" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "medicine_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "meal_timings" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "meal_timings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "test_categories" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "test_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "doctors" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "bmdcNumber" TEXT,
    "specialtyId" INTEGER,
    "chamber" TEXT,
    "phone" TEXT,
    "districtId" INTEGER,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "doctors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicines" (
    "id" UUID NOT NULL,
    "brandName" TEXT NOT NULL,
    "genericName" TEXT,
    "formId" INTEGER,
    "categoryId" INTEGER,
    "manufacturer" TEXT,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "medicines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "diagnostic_tests" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "categoryId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "diagnostic_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prescription_tests" (
    "prescriptionId" UUID NOT NULL,
    "testId" UUID NOT NULL,

    CONSTRAINT "prescription_tests_pkey" PRIMARY KEY ("prescriptionId","testId")
);

-- CreateTable
CREATE TABLE "notice_divisions" (
    "noticeId" UUID NOT NULL,
    "divisionId" INTEGER NOT NULL,

    CONSTRAINT "notice_divisions_pkey" PRIMARY KEY ("noticeId","divisionId")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "actorId" UUID,
    "subjectUserId" UUID,
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT,
    "before" JSONB,
    "after" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "genders_name_key" ON "genders"("name");

-- CreateIndex
CREATE UNIQUE INDEX "divisions_name_key" ON "divisions"("name");

-- CreateIndex
CREATE UNIQUE INDEX "districts_divisionId_name_key" ON "districts"("divisionId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "districts_id_divisionId_key" ON "districts"("id", "divisionId");

-- CreateIndex
CREATE UNIQUE INDEX "upazilas_districtId_name_key" ON "upazilas"("districtId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "upazilas_id_districtId_key" ON "upazilas"("id", "districtId");

-- CreateIndex
CREATE UNIQUE INDEX "doctor_specialties_name_key" ON "doctor_specialties"("name");

-- CreateIndex
CREATE UNIQUE INDEX "medicine_forms_name_key" ON "medicine_forms"("name");

-- CreateIndex
CREATE UNIQUE INDEX "medicine_categories_name_key" ON "medicine_categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "meal_timings_name_key" ON "meal_timings"("name");

-- CreateIndex
CREATE UNIQUE INDEX "test_categories_name_key" ON "test_categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "doctors_bmdcNumber_key" ON "doctors"("bmdcNumber");

-- CreateIndex
CREATE INDEX "doctors_name_idx" ON "doctors"("name");

-- CreateIndex
CREATE INDEX "medicines_genericName_idx" ON "medicines"("genericName");

-- CreateIndex
CREATE UNIQUE INDEX "medicines_brandName_formId_key" ON "medicines"("brandName", "formId");

-- CreateIndex
CREATE UNIQUE INDEX "diagnostic_tests_name_key" ON "diagnostic_tests"("name");

-- CreateIndex
CREATE INDEX "notice_divisions_divisionId_idx" ON "notice_divisions"("divisionId");

-- CreateIndex
CREATE INDEX "audit_logs_subjectUserId_createdAt_idx" ON "audit_logs"("subjectUserId", "createdAt");

-- CreateIndex
CREATE INDEX "audit_logs_actorId_createdAt_idx" ON "audit_logs"("actorId", "createdAt");

-- CreateIndex
CREATE INDEX "prescriptions_status_createdAt_idx" ON "prescriptions"("status", "createdAt");

-- CreateIndex
CREATE INDEX "prescriptions_doctorId_idx" ON "prescriptions"("doctorId");

-- CreateIndex
CREATE INDEX "prescription_medicines_prescriptionId_revision_idx" ON "prescription_medicines"("prescriptionId", "revision");

-- CreateIndex
CREATE INDEX "prescription_medicines_medicineId_idx" ON "prescription_medicines"("medicineId");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_genderId_fkey" FOREIGN KEY ("genderId") REFERENCES "genders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_divisionId_fkey" FOREIGN KEY ("divisionId") REFERENCES "divisions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_districtId_divisionId_fkey" FOREIGN KEY ("districtId", "divisionId") REFERENCES "districts"("id", "divisionId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_upazilaId_districtId_fkey" FOREIGN KEY ("upazilaId", "districtId") REFERENCES "upazilas"("id", "districtId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "doctors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_previousPrescriptionId_fkey" FOREIGN KEY ("previousPrescriptionId") REFERENCES "prescriptions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_medicineId_fkey" FOREIGN KEY ("medicineId") REFERENCES "medicines"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_mealTimingId_fkey" FOREIGN KEY ("mealTimingId") REFERENCES "meal_timings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_mealTimingId_fkey" FOREIGN KEY ("mealTimingId") REFERENCES "meal_timings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_lastEditedById_fkey" FOREIGN KEY ("lastEditedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notices" ADD CONSTRAINT "notices_approvedById_fkey" FOREIGN KEY ("approvedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "districts" ADD CONSTRAINT "districts_divisionId_fkey" FOREIGN KEY ("divisionId") REFERENCES "divisions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "upazilas" ADD CONSTRAINT "upazilas_districtId_fkey" FOREIGN KEY ("districtId") REFERENCES "districts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "doctors" ADD CONSTRAINT "doctors_specialtyId_fkey" FOREIGN KEY ("specialtyId") REFERENCES "doctor_specialties"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "doctors" ADD CONSTRAINT "doctors_districtId_fkey" FOREIGN KEY ("districtId") REFERENCES "districts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "doctors" ADD CONSTRAINT "doctors_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicines" ADD CONSTRAINT "medicines_formId_fkey" FOREIGN KEY ("formId") REFERENCES "medicine_forms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicines" ADD CONSTRAINT "medicines_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "medicine_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicines" ADD CONSTRAINT "medicines_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "diagnostic_tests" ADD CONSTRAINT "diagnostic_tests_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "test_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescription_tests" ADD CONSTRAINT "prescription_tests_prescriptionId_fkey" FOREIGN KEY ("prescriptionId") REFERENCES "prescriptions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescription_tests" ADD CONSTRAINT "prescription_tests_testId_fkey" FOREIGN KEY ("testId") REFERENCES "diagnostic_tests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notice_divisions" ADD CONSTRAINT "notice_divisions_noticeId_fkey" FOREIGN KEY ("noticeId") REFERENCES "notices"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notice_divisions" ADD CONSTRAINT "notice_divisions_divisionId_fkey" FOREIGN KEY ("divisionId") REFERENCES "divisions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_subjectUserId_fkey" FOREIGN KEY ("subjectUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Address levels fill top-down (Prisma can't express CHECK constraints). With
-- these, the composite foreign keys above always apply: a district must be in
-- the user's division and an upazila in the user's district.
ALTER TABLE "users" ADD CONSTRAINT "users_district_needs_division"
  CHECK ("districtId" IS NULL OR "divisionId" IS NOT NULL);
ALTER TABLE "users" ADD CONSTRAINT "users_upazila_needs_district"
  CHECK ("upazilaId" IS NULL OR "districtId" IS NOT NULL);
