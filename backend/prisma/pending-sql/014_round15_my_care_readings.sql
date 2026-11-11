-- Round 15: my care (conditions), structured readings, the doctor's limits,
-- care settings, habit / night ticks, care logs, questions for the doctor,
-- optional height. Additive only: existing health records keep their
-- display value and get NULL in the new columns (no data conversion).
-- Note: ALTER TYPE ... ADD VALUE runs in the same script; the new values
-- are not used in it, so this is safe on PostgreSQL 12+.

-- CreateEnum
CREATE TYPE "SugarContext" AS ENUM ('FASTING', 'AFTER_FOOD', 'BEFORE_BED', 'RANDOM');

-- CreateEnum
CREATE TYPE "BpArm" AS ENUM ('LEFT', 'RIGHT');

-- CreateEnum
CREATE TYPE "InjectionSite" AS ENUM ('LEFT_THIGH', 'RIGHT_THIGH', 'LEFT_ABDOMEN', 'RIGHT_ABDOMEN', 'LEFT_ARM', 'RIGHT_ARM');

-- CreateEnum
CREATE TYPE "InjectionGiver" AS ENUM ('SELF', 'FAMILY', 'NURSE');

-- CreateEnum
CREATE TYPE "RangeState" AS ENUM ('IN_RANGE', 'BELOW', 'ABOVE');

-- CreateEnum
CREATE TYPE "SugarUnit" AS ENUM ('MMOL', 'MGDL');

-- CreateEnum
CREATE TYPE "CareLogKind" AS ENUM ('SYMPTOMS', 'KICKS', 'RELIEVER', 'TD_DOSE');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "HealthRecordType" ADD VALUE 'INSULIN';
ALTER TYPE "HealthRecordType" ADD VALUE 'SLEEP';
ALTER TYPE "HealthRecordType" ADD VALUE 'WATER';
ALTER TYPE "HealthRecordType" ADD VALUE 'PEAK_FLOW';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "careStepDoneAt" TIMESTAMP(3),
ADD COLUMN     "heightCm" INTEGER;

-- AlterTable
ALTER TABLE "health_records" ADD COLUMN     "bpArm" "BpArm",
ADD COLUMN     "diastolic" INTEGER,
ADD COLUMN     "doseId" UUID,
ADD COLUMN     "enteredById" UUID,
ADD COLUMN     "injectionGiver" "InjectionGiver",
ADD COLUMN     "injectionSite" "InjectionSite",
ADD COLUMN     "measurements" INTEGER,
ADD COLUMN     "numericValue" DOUBLE PRECISION,
ADD COLUMN     "pulse" INTEGER,
ADD COLUMN     "rangeState" "RangeState",
ADD COLUMN     "sugarContext" "SugarContext",
ADD COLUMN     "systolic" INTEGER;

-- CreateTable
CREATE TABLE "conditions" (
    "id" SERIAL NOT NULL,
    "code" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameBn" TEXT NOT NULL,
    "subtitleEn" TEXT,
    "subtitleBn" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "conditions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_conditions" (
    "userId" UUID NOT NULL,
    "conditionId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_conditions_pkey" PRIMARY KEY ("userId","conditionId")
);

-- CreateTable
CREATE TABLE "health_limits" (
    "userId" UUID NOT NULL,
    "sugarUnit" "SugarUnit" NOT NULL DEFAULT 'MMOL',
    "fastingLow" DOUBLE PRECISION,
    "fastingHigh" DOUBLE PRECISION,
    "afterFoodHigh" DOUBLE PRECISION,
    "lowSugar" DOUBLE PRECISION,
    "hba1cTarget" DOUBLE PRECISION,
    "bpSystolicHigh" INTEGER,
    "bpDiastolicHigh" INTEGER,
    "bpSystolicLow" INTEGER,
    "bpCrisisSystolic" INTEGER,
    "bpCrisisDiastolic" INTEGER,
    "peakFlowBest" INTEGER,
    "weightGain3Days" DOUBLE PRECISION,
    "tshLow" DOUBLE PRECISION,
    "tshHigh" DOUBLE PRECISION,
    "fluidLimitMl" INTEGER,
    "feverAboveF" DOUBLE PRECISION,
    "weightGoalKg" DOUBLE PRECISION,
    "waterGlasses" INTEGER,
    "sleepHours" DOUBLE PRECISION,
    "notifyFamily" BOOLEAN NOT NULL DEFAULT true,
    "doctorNote" TEXT,
    "updatedById" UUID,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "health_limits_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "care_settings" (
    "userId" UUID NOT NULL,
    "conditionCode" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "updatedById" UUID,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "care_settings_pkey" PRIMARY KEY ("userId","conditionCode")
);

-- CreateTable
CREATE TABLE "day_ticks" (
    "userId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "day_ticks_pkey" PRIMARY KEY ("userId","key","day")
);

-- CreateTable
CREATE TABLE "care_logs" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "kind" "CareLogKind" NOT NULL,
    "conditionCode" TEXT,
    "loggedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "data" JSONB NOT NULL,
    "clientId" UUID,
    "enteredById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "care_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "doctor_questions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "text" TEXT NOT NULL,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "doctor_questions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "conditions_code_key" ON "conditions"("code");

-- CreateIndex
CREATE INDEX "care_logs_userId_kind_loggedAt_idx" ON "care_logs"("userId", "kind", "loggedAt");

-- CreateIndex
CREATE UNIQUE INDEX "care_logs_userId_clientId_key" ON "care_logs"("userId", "clientId");

-- CreateIndex
CREATE INDEX "doctor_questions_userId_createdAt_idx" ON "doctor_questions"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "user_conditions" ADD CONSTRAINT "user_conditions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_conditions" ADD CONSTRAINT "user_conditions_conditionId_fkey" FOREIGN KEY ("conditionId") REFERENCES "conditions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_limits" ADD CONSTRAINT "health_limits_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "care_settings" ADD CONSTRAINT "care_settings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "day_ticks" ADD CONSTRAINT "day_ticks_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "care_logs" ADD CONSTRAINT "care_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "doctor_questions" ADD CONSTRAINT "doctor_questions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Ranges the app offers (also checked by the API). Sugar limits in mmol/L.
ALTER TABLE "users" ADD CONSTRAINT "users_heightCm_check" CHECK ("heightCm" IS NULL OR "heightCm" BETWEEN 50 AND 250);
ALTER TABLE "health_records" ADD CONSTRAINT "health_records_measurements_check" CHECK ("measurements" IS NULL OR "measurements" BETWEEN 1 AND 2);
ALTER TABLE "health_limits" ADD CONSTRAINT "health_limits_sugar_check" CHECK (
  ("fastingLow" IS NULL OR "fastingLow" BETWEEN 1 AND 30) AND
  ("fastingHigh" IS NULL OR "fastingHigh" BETWEEN 1 AND 30) AND
  ("afterFoodHigh" IS NULL OR "afterFoodHigh" BETWEEN 1 AND 30) AND
  ("lowSugar" IS NULL OR "lowSugar" BETWEEN 1 AND 30) AND
  ("hba1cTarget" IS NULL OR "hba1cTarget" BETWEEN 4 AND 14));
ALTER TABLE "health_limits" ADD CONSTRAINT "health_limits_bp_check" CHECK (
  ("bpSystolicHigh" IS NULL OR "bpSystolicHigh" BETWEEN 90 AND 200) AND
  ("bpDiastolicHigh" IS NULL OR "bpDiastolicHigh" BETWEEN 50 AND 130) AND
  ("bpSystolicLow" IS NULL OR "bpSystolicLow" BETWEEN 60 AND 130) AND
  ("bpCrisisSystolic" IS NULL OR "bpCrisisSystolic" BETWEEN 140 AND 220) AND
  ("bpCrisisDiastolic" IS NULL OR "bpCrisisDiastolic" BETWEEN 90 AND 140));
ALTER TABLE "health_limits" ADD CONSTRAINT "health_limits_other_check" CHECK (
  ("peakFlowBest" IS NULL OR "peakFlowBest" BETWEEN 100 AND 800) AND
  ("weightGain3Days" IS NULL OR "weightGain3Days" BETWEEN 0.5 AND 5) AND
  ("tshLow" IS NULL OR "tshLow" BETWEEN 0.01 AND 10) AND
  ("tshHigh" IS NULL OR "tshHigh" BETWEEN 0.1 AND 20) AND
  ("fluidLimitMl" IS NULL OR "fluidLimitMl" BETWEEN 0 AND 5000) AND
  ("feverAboveF" IS NULL OR "feverAboveF" BETWEEN 98 AND 104) AND
  ("weightGoalKg" IS NULL OR "weightGoalKg" BETWEEN 20 AND 200) AND
  ("waterGlasses" IS NULL OR "waterGlasses" BETWEEN 1 AND 20) AND
  ("sleepHours" IS NULL OR "sleepHours" BETWEEN 3 AND 12));

-- The 8 conditions (owner edits names and subtitles; the code picks the page).
INSERT INTO "conditions" ("code", "nameEn", "nameBn", "subtitleEn", "subtitleBn", "sortOrder") VALUES
  ('diabetes', 'Diabetes', 'ডায়াবেটিস', 'Sugar, insulin, HbA1c', 'সুগার, ইনসুলিন, HbA1c', 1),
  ('bp', 'High blood pressure', 'উচ্চ রক্তচাপ', 'BP readings and medicine', 'প্রেসার মাপা ও ওষুধ', 2),
  ('heart', 'Heart disease', 'হৃদরোগ', 'Medicine and check-ups', 'ওষুধ ও চেকআপ', 3),
  ('kidney', 'Kidney disease', 'কিডনি রোগ', 'Tests and dialysis', 'টেস্ট ও ডায়ালাইসিস', 4),
  ('cancer', 'Cancer treatment', 'ক্যান্সার চিকিৎসা', 'Chemo and weekly tests', 'কেমো ও সাপ্তাহিক টেস্ট', 5),
  ('asthma', 'Asthma', 'শ্বাসকষ্ট, অ্যাজমা', 'Inhaler and medicine', 'ইনহেলার ও ওষুধ', 6),
  ('thyroid', 'Thyroid', 'থাইরয়েড', 'Daily medicine, tests', 'রোজকার ওষুধ, টেস্ট', 7),
  ('pregnancy', 'Pregnancy', 'গর্ভাবস্থা', 'Check-ups and vaccines', 'চেকআপ ও টিকা', 8)
ON CONFLICT ("code") DO NOTHING;
