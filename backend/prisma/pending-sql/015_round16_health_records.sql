-- Round 16: health records 2.0: private "my doctors", appointments (doctor
-- visits, pregnancy check-ups, chemo sessions), the test list (test_kinds and
-- their result fields, EN/BN, owner-edited), own upcoming tests and results,
-- record-only prescriptions, report / prescription photos. New tables only.

-- CreateEnum
CREATE TYPE "AppointmentKind" AS ENUM ('VISIT', 'ANC', 'CHEMO');

-- CreateEnum
CREATE TYPE "OwnTestStatus" AS ENUM ('UPCOMING', 'DONE');

-- CreateTable
CREATE TABLE "my_doctors" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "chamber" TEXT,
    "area" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "my_doctors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "appointments" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "kind" "AppointmentKind" NOT NULL DEFAULT 'VISIT',
    "date" DATE NOT NULL,
    "time" TEXT,
    "doctorId" UUID,
    "myDoctorId" UUID,
    "conditionCode" TEXT,
    "number" INTEGER,
    "note" TEXT,
    "remind" BOOLEAN NOT NULL DEFAULT true,
    "doneAt" TIMESTAMP(3),
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "appointments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "test_kinds" (
    "id" SERIAL NOT NULL,
    "code" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameBn" TEXT NOT NULL,
    "diagnosticTestId" UUID,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "test_kinds_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "test_kind_fields" (
    "id" SERIAL NOT NULL,
    "testKindId" INTEGER NOT NULL,
    "code" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameBn" TEXT NOT NULL,
    "unit" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "test_kind_fields_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "own_tests" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "testKindId" INTEGER,
    "otherName" TEXT,
    "status" "OwnTestStatus" NOT NULL DEFAULT 'UPCOMING',
    "date" DATE NOT NULL,
    "remind" BOOLEAN NOT NULL DEFAULT true,
    "fasting" BOOLEAN NOT NULL DEFAULT false,
    "findings" TEXT,
    "lab" TEXT,
    "conditionCode" TEXT,
    "healthReminderId" UUID,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "own_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "test_result_values" (
    "id" UUID NOT NULL,
    "ownTestId" UUID NOT NULL,
    "fieldId" INTEGER,
    "name" TEXT NOT NULL,
    "value" DOUBLE PRECISION,
    "textValue" TEXT,
    "unit" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "test_result_values_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "record_prescriptions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "date" DATE NOT NULL,
    "doctorId" UUID,
    "myDoctorId" UUID,
    "conditionCode" TEXT,
    "note" TEXT,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "record_prescriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "record_photos" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "ownTestId" UUID,
    "recordPrescriptionId" UUID,
    "imageUrl" TEXT NOT NULL,
    "page" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "record_photos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "my_doctors_userId_idx" ON "my_doctors"("userId");

-- CreateIndex
CREATE INDEX "appointments_userId_date_idx" ON "appointments"("userId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "test_kinds_code_key" ON "test_kinds"("code");

-- CreateIndex
CREATE UNIQUE INDEX "test_kind_fields_testKindId_code_key" ON "test_kind_fields"("testKindId", "code");

-- CreateIndex
CREATE INDEX "own_tests_userId_status_date_idx" ON "own_tests"("userId", "status", "date");

-- CreateIndex
CREATE INDEX "test_result_values_ownTestId_idx" ON "test_result_values"("ownTestId");

-- CreateIndex
CREATE INDEX "record_prescriptions_userId_date_idx" ON "record_prescriptions"("userId", "date");

-- CreateIndex
CREATE INDEX "record_photos_ownTestId_idx" ON "record_photos"("ownTestId");

-- CreateIndex
CREATE INDEX "record_photos_recordPrescriptionId_idx" ON "record_photos"("recordPrescriptionId");

-- AddForeignKey
ALTER TABLE "my_doctors" ADD CONSTRAINT "my_doctors_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "doctors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_myDoctorId_fkey" FOREIGN KEY ("myDoctorId") REFERENCES "my_doctors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "test_kinds" ADD CONSTRAINT "test_kinds_diagnosticTestId_fkey" FOREIGN KEY ("diagnosticTestId") REFERENCES "diagnostic_tests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "test_kind_fields" ADD CONSTRAINT "test_kind_fields_testKindId_fkey" FOREIGN KEY ("testKindId") REFERENCES "test_kinds"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "own_tests" ADD CONSTRAINT "own_tests_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "own_tests" ADD CONSTRAINT "own_tests_testKindId_fkey" FOREIGN KEY ("testKindId") REFERENCES "test_kinds"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "test_result_values" ADD CONSTRAINT "test_result_values_ownTestId_fkey" FOREIGN KEY ("ownTestId") REFERENCES "own_tests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "test_result_values" ADD CONSTRAINT "test_result_values_fieldId_fkey" FOREIGN KEY ("fieldId") REFERENCES "test_kind_fields"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "record_prescriptions" ADD CONSTRAINT "record_prescriptions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "record_prescriptions" ADD CONSTRAINT "record_prescriptions_doctorId_fkey" FOREIGN KEY ("doctorId") REFERENCES "doctors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "record_prescriptions" ADD CONSTRAINT "record_prescriptions_myDoctorId_fkey" FOREIGN KEY ("myDoctorId") REFERENCES "my_doctors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "record_photos" ADD CONSTRAINT "record_photos_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "record_photos" ADD CONSTRAINT "record_photos_ownTestId_fkey" FOREIGN KEY ("ownTestId") REFERENCES "own_tests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "record_photos" ADD CONSTRAINT "record_photos_recordPrescriptionId_fkey" FOREIGN KEY ("recordPrescriptionId") REFERENCES "record_prescriptions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Rules Prisma cannot express (also checked by the API).
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_one_doctor_check" CHECK ("doctorId" IS NULL OR "myDoctorId" IS NULL);
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_time_check" CHECK ("time" IS NULL OR "time" ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$');
ALTER TABLE "record_prescriptions" ADD CONSTRAINT "record_prescriptions_one_doctor_check" CHECK ("doctorId" IS NULL OR "myDoctorId" IS NULL);
ALTER TABLE "own_tests" ADD CONSTRAINT "own_tests_name_check" CHECK ("testKindId" IS NOT NULL OR "otherName" IS NOT NULL);
ALTER TABLE "record_photos" ADD CONSTRAINT "record_photos_one_owner_check" CHECK (("ownTestId" IS NULL) <> ("recordPrescriptionId" IS NULL));

-- The test list (from the owner's demo). The owner may link a kind to a
-- catalog test: UPDATE test_kinds SET "diagnosticTestId" = ... WHERE code = ...;
INSERT INTO "test_kinds" ("code", "nameEn", "nameBn", "sortOrder") VALUES
  ('hba1c', 'HbA1c', 'HbA1c', 1),
  ('cbc', 'Blood count (CBC)', 'রক্ত পরীক্ষা (CBC)', 2),
  ('kidney', 'Kidney (creatinine)', 'কিডনি (ক্রিয়েটিনিন)', 3),
  ('lipid', 'Lipid profile', 'লিপিড প্রোফাইল', 4),
  ('tsh', 'Thyroid (TSH)', 'থাইরয়েড (TSH)', 5),
  ('potassium', 'Potassium', 'পটাশিয়াম', 6),
  ('urine', 'Urine albumin', 'প্রস্রাবে অ্যালবুমিন', 7),
  ('egfr', 'eGFR (kidney function)', 'eGFR (কিডনির কাজ)', 8),
  ('hb', 'Haemoglobin (anaemia)', 'হিমোগ্লোবিন (রক্তস্বল্পতা)', 9),
  ('ogtt', 'Sugar test (OGTT)', 'সুগার টেস্ট (OGTT)', 10),
  ('ecg', 'ECG', 'ইসিজি', 11),
  ('echo', 'Echo (heart ultrasound)', 'ইকো (হার্টের আল্ট্রাসাউন্ড)', 12),
  ('eye', 'Eye check', 'চোখ পরীক্ষা', 13),
  ('usg', 'Ultrasound scan', 'আল্ট্রাসনোগ্রাম', 14),
  ('bgroup', 'Blood group', 'রক্তের গ্রুপ', 15),
  ('spiro', 'Lung test (spirometry)', 'ফুসফুস পরীক্ষা (স্পাইরোমেট্রি)', 16),
  ('checkup', 'Check-up', 'চেকআপ', 17)
ON CONFLICT ("code") DO NOTHING;

INSERT INTO "test_kind_fields" ("testKindId", "code", "nameEn", "nameBn", "unit", "sortOrder")
SELECT k."id", v."code", v."nameEn", v."nameBn", v."unit", v."sortOrder"
FROM (VALUES
  ('hba1c', 'hba1c', 'HbA1c', 'HbA1c', '%', 1),
  ('cbc', 'hb', 'Haemoglobin', 'হিমোগ্লোবিন', 'g/dL', 1),
  ('cbc', 'wbc', 'White cells (WBC)', 'শ্বেত রক্তকণিকা (WBC)', '×10³/µL', 2),
  ('cbc', 'plt', 'Platelets', 'প্লাটিলেট', '×10³/µL', 3),
  ('kidney', 'creat', 'Creatinine', 'ক্রিয়েটিনিন', 'mg/dL', 1),
  ('kidney', 'urea', 'Urea', 'ইউরিয়া', 'mg/dL', 2),
  ('lipid', 'tc', 'Total cholesterol', 'মোট কোলেস্টেরল', 'mg/dL', 1),
  ('lipid', 'ldl', 'LDL', 'LDL', 'mg/dL', 2),
  ('lipid', 'hdl', 'HDL', 'HDL', 'mg/dL', 3),
  ('lipid', 'tg', 'Triglycerides', 'ট্রাইগ্লিসারাইড', 'mg/dL', 4),
  ('tsh', 'tsh', 'TSH', 'TSH', 'mIU/L', 1),
  ('potassium', 'k', 'Potassium', 'পটাশিয়াম', 'mmol/L', 1),
  ('urine', 'acr', 'Albumin (ACR)', 'অ্যালবুমিন (ACR)', 'mg/g', 1),
  ('egfr', 'egfr', 'eGFR', 'eGFR', 'mL/min', 1),
  ('hb', 'hb', 'Haemoglobin', 'হিমোগ্লোবিন', 'g/dL', 1),
  ('ogtt', 'f', 'Fasting', 'খালি পেটে', 'mmol/L', 1),
  ('ogtt', 'h2', 'After 2 hours', '২ ঘণ্টা পর', 'mmol/L', 2),
  ('echo', 'ef', 'Ejection fraction (EF)', 'ইজেকশন ফ্র্যাকশন (EF)', '%', 1),
  ('bgroup', 'bg', 'Blood group', 'রক্তের গ্রুপ', NULL, 1),
  ('spiro', 'fev1', 'FEV1', 'FEV1', 'L', 1)
) AS v("kind", "code", "nameEn", "nameBn", "unit", "sortOrder")
JOIN "test_kinds" k ON k."code" = v."kind"
ON CONFLICT ("testKindId", "code") DO NOTHING;
