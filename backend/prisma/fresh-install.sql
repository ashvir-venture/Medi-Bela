-- Medi-Bela 0.1.0: full schema + reference data for an EMPTY database.
-- Generated from prisma/migrations/*, migrations_phase4a/phase4a_extra.sql
-- and every prisma/pending-sql file, in the order of docs/release/deploy-runbook.md.
-- Do not edit by hand: rebuild with `bash scripts/build-fresh-install.sh`.
-- Run once on a new, empty Neon database. If any statement fails, drop the
-- database, create it again and re-run; do not run it on a database with data.
-- Afterwards: SELECT count(*) FROM divisions;  -- 8
--             SELECT count(*) FROM districts;  -- 64
-- Then seed the staff accounts (runbook step 3).

-- Prisma's migration history, so `prisma migrate status` sees every
-- migration as applied.
CREATE TABLE IF NOT EXISTS "_prisma_migrations" (
    "id"                  VARCHAR(36) PRIMARY KEY NOT NULL,
    "checksum"            VARCHAR(64) NOT NULL,
    "finished_at"         TIMESTAMPTZ,
    "migration_name"      VARCHAR(255) NOT NULL,
    "logs"                TEXT,
    "rolled_back_at"      TIMESTAMPTZ,
    "started_at"          TIMESTAMPTZ NOT NULL DEFAULT now(),
    "applied_steps_count" INTEGER NOT NULL DEFAULT 0
);

-- ===== migration 20260831111054_init =====
-- CreateEnum
CREATE TYPE "Role" AS ENUM ('USER', 'ADMIN', 'PHARMACIST');

-- CreateEnum
CREATE TYPE "AccountStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'DELETED');

-- CreateEnum
CREATE TYPE "Language" AS ENUM ('EN', 'BN');

-- CreateEnum
CREATE TYPE "FamilyRole" AS ENUM ('OWNER', 'MEMBER');

-- CreateEnum
CREATE TYPE "InvitationStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "PrescriptionStatus" AS ENUM ('PENDING', 'COMPLETED', 'REJECTED');

-- CreateEnum
CREATE TYPE "DoseStatus" AS ENUM ('PENDING', 'TAKEN', 'MISSED', 'SKIPPED');

-- CreateEnum
CREATE TYPE "HealthReminderStatus" AS ENUM ('PENDING', 'COMPLETED', 'DISMISSED');

-- CreateEnum
CREATE TYPE "HealthRecordType" AS ENUM ('BLOOD_PRESSURE', 'BLOOD_SUGAR', 'WEIGHT', 'TEMPERATURE', 'HEART_RATE', 'OTHER');

-- CreateEnum
CREATE TYPE "NoticeStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "NoticeAudience" AS ENUM ('ALL', 'USER', 'ADMIN');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('MEDICINE_REMINDER', 'MISSED_DOSE_FAMILY_ALERT', 'NOTICE', 'SYSTEM');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT,
    "passwordHash" TEXT NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'USER',
    "accountStatus" "AccountStatus" NOT NULL DEFAULT 'ACTIVE',
    "languagePreference" "Language" NOT NULL DEFAULT 'EN',
    "notificationsEnabled" BOOLEAN NOT NULL DEFAULT true,
    "profileVisibleToFamily" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "families" (
    "id" UUID NOT NULL,
    "name" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "families_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_members" (
    "id" UUID NOT NULL,
    "familyId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" "FamilyRole" NOT NULL DEFAULT 'MEMBER',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "family_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_invitations" (
    "id" UUID NOT NULL,
    "familyId" UUID NOT NULL,
    "invitedPhone" TEXT NOT NULL,
    "invitedById" UUID NOT NULL,
    "status" "InvitationStatus" NOT NULL DEFAULT 'PENDING',
    "respondedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "family_invitations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prescriptions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "imageUrl" TEXT NOT NULL,
    "status" "PrescriptionStatus" NOT NULL DEFAULT 'PENDING',
    "reviewedById" UUID,
    "reviewedAt" TIMESTAMP(3),
    "rejectionReason" TEXT,
    "processingNote" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "prescriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prescription_medicines" (
    "id" UUID NOT NULL,
    "prescriptionId" UUID NOT NULL,
    "medicineName" TEXT NOT NULL,
    "dosage" TEXT NOT NULL,
    "frequency" TEXT NOT NULL,
    "duration" TEXT NOT NULL,
    "instructions" TEXT,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "verifiedById" UUID,
    "verifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "prescription_medicines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicine_routines" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "prescriptionMedicineId" UUID,
    "medicineName" TEXT NOT NULL,
    "dosage" TEXT NOT NULL,
    "frequency" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "medicine_routines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicine_doses" (
    "id" UUID NOT NULL,
    "routineId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "scheduledAt" TIMESTAMP(3) NOT NULL,
    "status" "DoseStatus" NOT NULL DEFAULT 'PENDING',
    "takenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "medicine_doses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "health_reminders" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "sourceRuleId" UUID,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "scheduledAt" TIMESTAMP(3) NOT NULL,
    "status" "HealthReminderStatus" NOT NULL DEFAULT 'PENDING',
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "health_reminders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "health_records" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "type" "HealthRecordType" NOT NULL,
    "value" TEXT NOT NULL,
    "unit" TEXT,
    "notes" TEXT,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "health_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "health_suggestion_rules" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "conditionType" TEXT NOT NULL,
    "conditionValue" TEXT NOT NULL,
    "suggestedAction" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "health_suggestion_rules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notices" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "status" "NoticeStatus" NOT NULL DEFAULT 'DRAFT',
    "audience" "NoticeAudience" NOT NULL DEFAULT 'ALL',
    "publishedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "relatedEntityId" TEXT,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE INDEX "users_role_idx" ON "users"("role");

-- CreateIndex
CREATE INDEX "family_members_userId_idx" ON "family_members"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "family_members_familyId_userId_key" ON "family_members"("familyId", "userId");

-- CreateIndex
CREATE INDEX "family_invitations_invitedPhone_idx" ON "family_invitations"("invitedPhone");

-- CreateIndex
CREATE INDEX "family_invitations_familyId_status_idx" ON "family_invitations"("familyId", "status");

-- CreateIndex
CREATE INDEX "prescriptions_userId_status_idx" ON "prescriptions"("userId", "status");

-- CreateIndex
CREATE INDEX "prescriptions_status_idx" ON "prescriptions"("status");

-- CreateIndex
CREATE INDEX "prescription_medicines_prescriptionId_idx" ON "prescription_medicines"("prescriptionId");

-- CreateIndex
CREATE INDEX "medicine_routines_userId_active_idx" ON "medicine_routines"("userId", "active");

-- CreateIndex
CREATE INDEX "medicine_doses_userId_scheduledAt_idx" ON "medicine_doses"("userId", "scheduledAt");

-- CreateIndex
CREATE INDEX "medicine_doses_routineId_scheduledAt_idx" ON "medicine_doses"("routineId", "scheduledAt");

-- CreateIndex
CREATE INDEX "health_reminders_userId_scheduledAt_idx" ON "health_reminders"("userId", "scheduledAt");

-- CreateIndex
CREATE INDEX "health_reminders_userId_status_idx" ON "health_reminders"("userId", "status");

-- CreateIndex
CREATE INDEX "health_records_userId_type_recordedAt_idx" ON "health_records"("userId", "type", "recordedAt");

-- CreateIndex
CREATE INDEX "health_suggestion_rules_enabled_idx" ON "health_suggestion_rules"("enabled");

-- CreateIndex
CREATE INDEX "notices_status_publishedAt_idx" ON "notices"("status", "publishedAt");

-- CreateIndex
CREATE INDEX "notifications_userId_isRead_idx" ON "notifications"("userId", "isRead");

-- CreateIndex
CREATE INDEX "notifications_userId_createdAt_idx" ON "notifications"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_invitations" ADD CONSTRAINT "family_invitations_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_invitations" ADD CONSTRAINT "family_invitations_invitedById_fkey" FOREIGN KEY ("invitedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_prescriptionId_fkey" FOREIGN KEY ("prescriptionId") REFERENCES "prescriptions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescription_medicines" ADD CONSTRAINT "prescription_medicines_verifiedById_fkey" FOREIGN KEY ("verifiedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_prescriptionMedicineId_fkey" FOREIGN KEY ("prescriptionMedicineId") REFERENCES "prescription_medicines"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_doses" ADD CONSTRAINT "medicine_doses_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "medicine_routines"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_doses" ADD CONSTRAINT "medicine_doses_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_reminders" ADD CONSTRAINT "health_reminders_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_reminders" ADD CONSTRAINT "health_reminders_sourceRuleId_fkey" FOREIGN KEY ("sourceRuleId") REFERENCES "health_suggestion_rules"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_records" ADD CONSTRAINT "health_records_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_suggestion_rules" ADD CONSTRAINT "health_suggestion_rules_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notices" ADD CONSTRAINT "notices_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '5d45dacf6881d25cc303f23be9c99c143d5674e914795b3f1b2f25da8a24a4ee', now(), '20260831111054_init', 1);

-- ===== migration 20260901105437_refresh_token =====
-- AlterTable
ALTER TABLE "users" ADD COLUMN     "hashedRefreshToken" TEXT;

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, 'd50ad9eb7b3589d616afcd566c040697580e8b25d4d2aaffc52400f8cfaf9277', now(), '20260901105437_refresh_token', 1);

-- ===== migration 20260908000000_prescription_medicine_structured_fields =====
-- Phase 3A: prescription upload idempotency + structured fields needed for
-- deterministic routine generation. Purely additive — no existing columns
-- are altered or dropped, so no existing data is broken.

-- Prescription: idempotency key for offline upload retries
ALTER TABLE "prescriptions"
  ADD COLUMN "clientUploadId" TEXT;

CREATE UNIQUE INDEX "prescriptions_clientUploadId_key"
  ON "prescriptions" ("clientUploadId");

-- PrescriptionMedicine: structured fields consumed by routine generation.
-- Nullable because they only need to be populated (and validated) at the
-- point a prescription is completed, not while still being drafted.
ALTER TABLE "prescription_medicines"
  ADD COLUMN "timesPerDay" INTEGER,
  ADD COLUMN "scheduleTimes" TEXT,
  ADD COLUMN "durationDays" INTEGER,
  ADD COLUMN "startDate" TIMESTAMP(3);

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '77c23bc47b7a3ff43f15c2bef3ac59e8cb2840725cfcfe9d3bd6291afd29bff6', now(), '20260908000000_prescription_medicine_structured_fields', 1);

-- ===== migration 20260913161608_update_prescription_fields =====
/*
  Warnings:

  - You are about to drop the column `durationDays` on the `prescription_medicines` table. All the data in the column will be lost.
  - You are about to drop the column `scheduleTimes` on the `prescription_medicines` table. All the data in the column will be lost.
  - You are about to drop the column `startDate` on the `prescription_medicines` table. All the data in the column will be lost.
  - You are about to drop the column `timesPerDay` on the `prescription_medicines` table. All the data in the column will be lost.
  - You are about to drop the column `clientUploadId` on the `prescriptions` table. All the data in the column will be lost.

*/
-- DropIndex
DROP INDEX "prescriptions_clientUploadId_key";

-- AlterTable
ALTER TABLE "prescription_medicines" DROP COLUMN "durationDays",
DROP COLUMN "scheduleTimes",
DROP COLUMN "startDate",
DROP COLUMN "timesPerDay";

-- AlterTable
ALTER TABLE "prescriptions" DROP COLUMN "clientUploadId";

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '2b0cbef6e9fec8e6093d468eabf7f30d793028dd7ddcc0270ca3f99edd975bc7', now(), '20260913161608_update_prescription_fields', 1);

-- ===== migration 20260913162450_add_prescription_structured_fields =====
/*
  Warnings:

  - A unique constraint covering the columns `[clientUploadId]` on the table `prescriptions` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "prescription_medicines" ADD COLUMN     "durationDays" INTEGER,
ADD COLUMN     "scheduleTimes" TEXT,
ADD COLUMN     "startDate" TIMESTAMP(3),
ADD COLUMN     "timesPerDay" INTEGER;

-- AlterTable
ALTER TABLE "prescriptions" ADD COLUMN     "clientUploadId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "prescriptions_clientUploadId_key" ON "prescriptions"("clientUploadId");

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '5aba429b675f305ad59c404ea272c1969e725095e4a749feee60e4fe69b967be', now(), '20260913162450_add_prescription_structured_fields', 1);

-- ===== migration 20260922104148_add_health_suggestions =====
-- CreateEnum
CREATE TYPE "SuggestionStatus" AS ENUM ('DRAFT', 'PUBLISHED');

-- CreateTable
CREATE TABLE "health_suggestions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "itemsEn" JSONB NOT NULL,
    "itemsBn" JSONB NOT NULL,
    "sourceMedicines" TEXT NOT NULL,
    "status" "SuggestionStatus" NOT NULL DEFAULT 'DRAFT',
    "publishedById" UUID,
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "health_suggestions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "health_suggestions_userId_status_idx" ON "health_suggestions"("userId", "status");

-- CreateIndex
CREATE INDEX "health_suggestions_status_publishedAt_idx" ON "health_suggestions"("status", "publishedAt");

-- AddForeignKey
ALTER TABLE "health_suggestions" ADD CONSTRAINT "health_suggestions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_suggestions" ADD CONSTRAINT "health_suggestions_publishedById_fkey" FOREIGN KEY ("publishedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '18321f8aeb2a0a5daa3e9d5c86d5b3943f5bda56ce09989bc615243ded81a984', now(), '20260922104148_add_health_suggestions', 1);

-- ===== migration 20261015203147_final =====
/*
  Warnings:

  - You are about to drop the column `hashedRefreshToken` on the `users` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[userId]` on the table `family_members` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[userId,clientId]` on the table `health_records` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[userId,type,relatedEntityId]` on the table `notifications` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "PushStatus" AS ENUM ('PENDING', 'SENT', 'FAILED', 'SKIPPED');

-- CreateEnum
CREATE TYPE "DevicePlatform" AS ENUM ('ANDROID', 'IOS');

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'PRESCRIPTION_UPDATE';

-- DropIndex
DROP INDEX "family_members_userId_idx";

-- DropIndex
DROP INDEX "health_suggestions_status_publishedAt_idx";

-- AlterTable
ALTER TABLE "health_records" ADD COLUMN     "clientId" UUID;

-- AlterTable
ALTER TABLE "medicine_doses" ADD COLUMN     "familyAlertProcessedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "data" JSONB,
ADD COLUMN     "pushAttempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "pushStatus" "PushStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "pushedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "users" DROP COLUMN "hashedRefreshToken";

-- CreateTable
CREATE TABLE "device_tokens" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "tokenEnc" TEXT NOT NULL,
    "platform" "DevicePlatform" NOT NULL,
    "appVersion" TEXT,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "device_tokens_tokenHash_key" ON "device_tokens"("tokenHash");

-- CreateIndex
CREATE INDEX "device_tokens_userId_idx" ON "device_tokens"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "family_members_userId_key" ON "family_members"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "health_records_userId_clientId_key" ON "health_records"("userId", "clientId");

-- CreateIndex
CREATE INDEX "medicine_doses_status_scheduledAt_idx" ON "medicine_doses"("status", "scheduledAt");

-- CreateIndex
CREATE INDEX "notifications_pushStatus_createdAt_idx" ON "notifications"("pushStatus", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_userId_type_relatedEntityId_key" ON "notifications"("userId", "type", "relatedEntityId");

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '86d41008e0ce6607dbde334c31babbf5737d6f76b18714546ad25c7d2f929c72', now(), '20261015203147_final', 1);

-- ===== migration 20261019120000_assistant_conversations =====
-- CreateEnum
CREATE TYPE "AssistantConversationStatus" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "AssistantMessageRole" AS ENUM ('USER', 'ASSISTANT');

-- CreateTable
CREATE TABLE "assistant_conversations" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "status" "AssistantConversationStatus" NOT NULL DEFAULT 'OPEN',
    "userMessageCount" INTEGER NOT NULL DEFAULT 0,
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "assistant_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assistant_messages" (
    "id" UUID NOT NULL,
    "conversationId" UUID NOT NULL,
    "seq" INTEGER NOT NULL,
    "role" "AssistantMessageRole" NOT NULL,
    "content" TEXT NOT NULL,
    "kind" TEXT,
    "language" "Language",
    "clientMessageId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "assistant_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "assistant_conversations_userId_updatedAt_idx" ON "assistant_conversations"("userId", "updatedAt");

-- CreateIndex
CREATE UNIQUE INDEX "assistant_messages_conversationId_seq_key" ON "assistant_messages"("conversationId", "seq");

-- CreateIndex
CREATE UNIQUE INDEX "assistant_messages_conversationId_clientMessageId_key" ON "assistant_messages"("conversationId", "clientMessageId");

-- AddForeignKey
ALTER TABLE "assistant_conversations" ADD CONSTRAINT "assistant_conversations_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_messages" ADD CONSTRAINT "assistant_messages_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "assistant_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Database-level backstop for the 10-user-message limit (Prisma does not model
-- CHECK constraints; it neither manages nor drops this one). If the limit in
-- AssistantService (MAX_USER_MESSAGES) is ever changed, change this too.
ALTER TABLE "assistant_conversations"
  ADD CONSTRAINT "assistant_conversations_userMessageCount_check"
  CHECK ("userMessageCount" >= 0 AND "userMessageCount" <= 10);

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, 'ff85954204d10ddc7218c27d71b01096c972a5a589aac8d07d0133efd726a0ed', now(), '20261019120000_assistant_conversations', 1);

-- ===== migration 20261020120000_suggestion_routine_link =====
-- AlterTable
ALTER TABLE "health_suggestions" ADD COLUMN "routineId" UUID;

-- CreateIndex
CREATE INDEX "health_suggestions_routineId_createdAt_idx" ON "health_suggestions"("routineId", "createdAt");

-- AddForeignKey
ALTER TABLE "health_suggestions" ADD CONSTRAINT "health_suggestions_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "medicine_routines"("id") ON DELETE SET NULL ON UPDATE CASCADE;

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, '1bc89a8bce2465bb0199b93b6850319b490e7d39fe433b4ca5e7d2f3845f8531', now(), '20261020120000_suggestion_routine_link', 1);

-- ===== migration 20261021120000_password_reset_and_account_deletion =====
-- AlterTable
ALTER TABLE "users" ADD COLUMN "passwordChangedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "password_reset_codes" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "codeHash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_codes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "password_reset_codes_userId_key" ON "password_reset_codes"("userId");

-- AddForeignKey
ALTER TABLE "password_reset_codes" ADD CONSTRAINT "password_reset_codes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

INSERT INTO "_prisma_migrations" ("id","checksum","finished_at","migration_name","applied_steps_count") VALUES (gen_random_uuid()::text, 'e608faf3dbdc6d2634bce79ac6700fb0abdfac7505985257b94194bd1438a084', now(), '20261021120000_password_reset_and_account_deletion', 1);

-- ===== migrations_phase4a/phase4a_extra.sql =====
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


-- ===== prisma/pending-sql/001_round3_reminder_and_notice_toggles.sql =====
-- Round 3: separate medicine-reminder and notice switches (default on).
ALTER TABLE "users" ADD COLUMN "medicineRemindersEnabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "noticesEnabled" BOOLEAN NOT NULL DEFAULT true;


-- ===== prisma/pending-sql/002_round4_schema.sql =====
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


-- ===== prisma/pending-sql/003_round4_reference_data.sql =====
-- Round 4 reference data (English only). Every dropdown reads these tables;
-- add or edit rows here or directly in the database. Safe to re-run.
-- Address data: divisions, districts and upazilas of Bangladesh from
-- github.com/nuhil/bangladesh-geocode (ids kept so districts/upazilas point
-- at the right parent). Spellings follow that source, e.g. "Chattagram".

INSERT INTO "divisions" ("id", "name") VALUES
  (1, 'Chattagram'),
  (2, 'Rajshahi'),
  (3, 'Khulna'),
  (4, 'Barisal'),
  (5, 'Sylhet'),
  (6, 'Dhaka'),
  (7, 'Rangpur'),
  (8, 'Mymensingh')
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "districts" ("id", "divisionId", "name") VALUES
  (1, 1, 'Comilla'),
  (2, 1, 'Feni'),
  (3, 1, 'Brahmanbaria'),
  (4, 1, 'Rangamati'),
  (5, 1, 'Noakhali'),
  (6, 1, 'Chandpur'),
  (7, 1, 'Lakshmipur'),
  (8, 1, 'Chattogram'),
  (9, 1, 'Coxsbazar'),
  (10, 1, 'Khagrachhari'),
  (11, 1, 'Bandarban'),
  (12, 2, 'Sirajganj'),
  (13, 2, 'Pabna'),
  (14, 2, 'Bogura'),
  (15, 2, 'Rajshahi'),
  (16, 2, 'Natore'),
  (17, 2, 'Joypurhat'),
  (18, 2, 'Chapainawabganj'),
  (19, 2, 'Naogaon'),
  (20, 3, 'Jashore'),
  (21, 3, 'Satkhira'),
  (22, 3, 'Meherpur'),
  (23, 3, 'Narail'),
  (24, 3, 'Chuadanga'),
  (25, 3, 'Kushtia'),
  (26, 3, 'Magura'),
  (27, 3, 'Khulna'),
  (28, 3, 'Bagerhat'),
  (29, 3, 'Jhenaidah'),
  (30, 4, 'Jhalakathi'),
  (31, 4, 'Patuakhali'),
  (32, 4, 'Pirojpur'),
  (33, 4, 'Barisal'),
  (34, 4, 'Bhola'),
  (35, 4, 'Barguna'),
  (36, 5, 'Sylhet'),
  (37, 5, 'Moulvibazar'),
  (38, 5, 'Habiganj'),
  (39, 5, 'Sunamganj'),
  (40, 6, 'Narsingdi'),
  (41, 6, 'Gazipur'),
  (42, 6, 'Shariatpur'),
  (43, 6, 'Narayanganj'),
  (44, 6, 'Tangail'),
  (45, 6, 'Kishoreganj'),
  (46, 6, 'Manikganj'),
  (47, 6, 'Dhaka'),
  (48, 6, 'Munshiganj'),
  (49, 6, 'Rajbari'),
  (50, 6, 'Madaripur'),
  (51, 6, 'Gopalganj'),
  (52, 6, 'Faridpur'),
  (53, 7, 'Panchagarh'),
  (54, 7, 'Dinajpur'),
  (55, 7, 'Lalmonirhat'),
  (56, 7, 'Nilphamari'),
  (57, 7, 'Gaibandha'),
  (58, 7, 'Thakurgaon'),
  (59, 7, 'Rangpur'),
  (60, 7, 'Kurigram'),
  (61, 8, 'Sherpur'),
  (62, 8, 'Mymensingh'),
  (63, 8, 'Jamalpur'),
  (64, 8, 'Netrokona')
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "upazilas" ("id", "districtId", "name") VALUES
  (1, 1, 'Debidwar'),
  (2, 1, 'Barura'),
  (3, 1, 'Brahmanpara'),
  (4, 1, 'Chandina'),
  (5, 1, 'Chauddagram'),
  (6, 1, 'Daudkandi'),
  (7, 1, 'Homna'),
  (8, 1, 'Laksam'),
  (9, 1, 'Muradnagar'),
  (10, 1, 'Nangalkot'),
  (11, 1, 'Comilla Sadar'),
  (12, 1, 'Meghna'),
  (13, 1, 'Monohargonj'),
  (14, 1, 'Sadarsouth'),
  (15, 1, 'Titas'),
  (16, 1, 'Burichang'),
  (17, 1, 'Lalmai'),
  (18, 2, 'Chhagalnaiya'),
  (19, 2, 'Feni Sadar'),
  (20, 2, 'Sonagazi'),
  (21, 2, 'Fulgazi'),
  (22, 2, 'Parshuram'),
  (23, 2, 'Daganbhuiyan'),
  (24, 3, 'Brahmanbaria Sadar'),
  (25, 3, 'Kasba'),
  (26, 3, 'Nasirnagar'),
  (27, 3, 'Sarail'),
  (28, 3, 'Ashuganj'),
  (29, 3, 'Akhaura'),
  (30, 3, 'Nabinagar'),
  (31, 3, 'Bancharampur'),
  (32, 3, 'Bijoynagar'),
  (33, 4, 'Rangamati Sadar'),
  (34, 4, 'Kaptai'),
  (35, 4, 'Kawkhali'),
  (36, 4, 'Baghaichari'),
  (37, 4, 'Barkal'),
  (38, 4, 'Langadu'),
  (39, 4, 'Rajasthali'),
  (40, 4, 'Belaichari'),
  (41, 4, 'Juraichari'),
  (42, 4, 'Naniarchar'),
  (43, 5, 'Noakhali Sadar'),
  (44, 5, 'Companiganj'),
  (45, 5, 'Begumganj'),
  (46, 5, 'Hatia'),
  (47, 5, 'Subarnachar'),
  (48, 5, 'Kabirhat'),
  (49, 5, 'Senbug'),
  (50, 5, 'Chatkhil'),
  (51, 5, 'Sonaimori'),
  (52, 6, 'Haimchar'),
  (53, 6, 'Kachua'),
  (54, 6, 'Shahrasti'),
  (55, 6, 'Chandpur Sadar'),
  (56, 6, 'Matlab South'),
  (57, 6, 'Hajiganj'),
  (58, 6, 'Matlab North'),
  (59, 6, 'Faridgonj'),
  (60, 7, 'Lakshmipur Sadar'),
  (61, 7, 'Kamalnagar'),
  (62, 7, 'Raipur'),
  (63, 7, 'Ramgati'),
  (64, 7, 'Ramganj'),
  (65, 8, 'Rangunia'),
  (66, 8, 'Sitakunda'),
  (67, 8, 'Mirsharai'),
  (68, 8, 'Patiya'),
  (69, 8, 'Sandwip'),
  (70, 8, 'Banshkhali'),
  (71, 8, 'Boalkhali'),
  (72, 8, 'Anwara'),
  (73, 8, 'Chandanaish'),
  (74, 8, 'Satkania'),
  (75, 8, 'Lohagara'),
  (76, 8, 'Hathazari'),
  (77, 8, 'Fatikchhari'),
  (78, 8, 'Raozan'),
  (79, 8, 'Karnafuli'),
  (80, 9, 'Coxsbazar Sadar'),
  (81, 9, 'Chakaria'),
  (82, 9, 'Kutubdia'),
  (83, 9, 'Ukhiya'),
  (84, 9, 'Moheshkhali'),
  (85, 9, 'Pekua'),
  (86, 9, 'Ramu'),
  (87, 9, 'Teknaf'),
  (88, 10, 'Khagrachhari Sadar'),
  (89, 10, 'Dighinala'),
  (90, 10, 'Panchari'),
  (91, 10, 'Laxmichhari'),
  (92, 10, 'Mohalchari'),
  (93, 10, 'Manikchari'),
  (94, 10, 'Ramgarh'),
  (95, 10, 'Matiranga'),
  (96, 10, 'Guimara'),
  (97, 11, 'Bandarban Sadar'),
  (98, 11, 'Alikadam'),
  (99, 11, 'Naikhongchhari'),
  (100, 11, 'Rowangchhari'),
  (101, 11, 'Lama'),
  (102, 11, 'Ruma'),
  (103, 11, 'Thanchi'),
  (104, 12, 'Belkuchi'),
  (105, 12, 'Chauhali'),
  (106, 12, 'Kamarkhand'),
  (107, 12, 'Kazipur'),
  (108, 12, 'Raigonj'),
  (109, 12, 'Shahjadpur'),
  (110, 12, 'Sirajganj Sadar'),
  (111, 12, 'Tarash'),
  (112, 12, 'Ullapara'),
  (113, 13, 'Sujanagar'),
  (114, 13, 'Ishurdi'),
  (115, 13, 'Bhangura'),
  (116, 13, 'Pabna Sadar'),
  (117, 13, 'Bera'),
  (118, 13, 'Atghoria'),
  (119, 13, 'Chatmohar'),
  (120, 13, 'Santhia'),
  (121, 13, 'Faridpur'),
  (122, 14, 'Kahaloo'),
  (123, 14, 'Bogra Sadar'),
  (124, 14, 'Shariakandi'),
  (125, 14, 'Shajahanpur'),
  (126, 14, 'Dupchanchia'),
  (127, 14, 'Adamdighi'),
  (128, 14, 'Nondigram'),
  (129, 14, 'Sonatala'),
  (130, 14, 'Dhunot'),
  (131, 14, 'Gabtali'),
  (132, 14, 'Sherpur'),
  (133, 14, 'Shibganj'),
  (134, 15, 'Paba'),
  (135, 15, 'Durgapur'),
  (136, 15, 'Mohonpur'),
  (137, 15, 'Charghat'),
  (138, 15, 'Puthia'),
  (139, 15, 'Bagha'),
  (140, 15, 'Godagari'),
  (141, 15, 'Tanore'),
  (142, 15, 'Bagmara'),
  (143, 16, 'Natore Sadar'),
  (144, 16, 'Singra'),
  (145, 16, 'Baraigram'),
  (146, 16, 'Bagatipara'),
  (147, 16, 'Lalpur'),
  (148, 16, 'Gurudaspur'),
  (149, 16, 'Naldanga'),
  (150, 17, 'Akkelpur'),
  (151, 17, 'Kalai'),
  (152, 17, 'Khetlal'),
  (153, 17, 'Panchbibi'),
  (154, 17, 'Joypurhat Sadar'),
  (155, 18, 'Chapainawabganj Sadar'),
  (156, 18, 'Gomostapur'),
  (157, 18, 'Nachol'),
  (158, 18, 'Bholahat'),
  (159, 18, 'Shibganj'),
  (160, 19, 'Mohadevpur'),
  (161, 19, 'Badalgachi'),
  (162, 19, 'Patnitala'),
  (163, 19, 'Dhamoirhat'),
  (164, 19, 'Niamatpur'),
  (165, 19, 'Manda'),
  (166, 19, 'Atrai'),
  (167, 19, 'Raninagar'),
  (168, 19, 'Naogaon Sadar'),
  (169, 19, 'Porsha'),
  (170, 19, 'Sapahar'),
  (171, 20, 'Manirampur'),
  (172, 20, 'Abhaynagar'),
  (173, 20, 'Bagherpara'),
  (174, 20, 'Chougachha'),
  (175, 20, 'Jhikargacha'),
  (176, 20, 'Keshabpur'),
  (177, 20, 'Jessore Sadar'),
  (178, 20, 'Sharsha'),
  (179, 21, 'Assasuni'),
  (180, 21, 'Debhata'),
  (181, 21, 'Kalaroa'),
  (182, 21, 'Satkhira Sadar'),
  (183, 21, 'Shyamnagar'),
  (184, 21, 'Tala'),
  (185, 21, 'Kaliganj'),
  (186, 22, 'Mujibnagar'),
  (187, 22, 'Meherpur Sadar'),
  (188, 22, 'Gangni'),
  (189, 23, 'Narail Sadar'),
  (190, 23, 'Lohagara'),
  (191, 23, 'Kalia'),
  (192, 24, 'Chuadanga Sadar'),
  (193, 24, 'Alamdanga'),
  (194, 24, 'Damurhuda'),
  (195, 24, 'Jibannagar'),
  (196, 25, 'Kushtia Sadar'),
  (197, 25, 'Kumarkhali'),
  (198, 25, 'Khoksa'),
  (199, 25, 'Mirpur'),
  (200, 25, 'Daulatpur'),
  (201, 25, 'Bheramara'),
  (202, 26, 'Shalikha'),
  (203, 26, 'Sreepur'),
  (204, 26, 'Magura Sadar'),
  (205, 26, 'Mohammadpur'),
  (206, 27, 'Paikgasa'),
  (207, 27, 'Fultola'),
  (208, 27, 'Digholia'),
  (209, 27, 'Rupsha'),
  (210, 27, 'Terokhada'),
  (211, 27, 'Dumuria'),
  (212, 27, 'Botiaghata'),
  (213, 27, 'Dakop'),
  (214, 27, 'Koyra'),
  (215, 28, 'Fakirhat'),
  (216, 28, 'Bagerhat Sadar'),
  (217, 28, 'Mollahat'),
  (218, 28, 'Sarankhola'),
  (219, 28, 'Rampal'),
  (220, 28, 'Morrelganj'),
  (221, 28, 'Kachua'),
  (222, 28, 'Mongla'),
  (223, 28, 'Chitalmari'),
  (224, 29, 'Jhenaidah Sadar'),
  (225, 29, 'Shailkupa'),
  (226, 29, 'Harinakundu'),
  (227, 29, 'Kaliganj'),
  (228, 29, 'Kotchandpur'),
  (229, 29, 'Moheshpur'),
  (230, 30, 'Jhalakathi Sadar'),
  (231, 30, 'Kathalia'),
  (232, 30, 'Nalchity'),
  (233, 30, 'Rajapur'),
  (234, 31, 'Bauphal'),
  (235, 31, 'Patuakhali Sadar'),
  (236, 31, 'Dumki'),
  (237, 31, 'Dashmina'),
  (238, 31, 'Kalapara'),
  (239, 31, 'Mirzaganj'),
  (240, 31, 'Galachipa'),
  (241, 31, 'Rangabali'),
  (242, 32, 'Pirojpur Sadar'),
  (243, 32, 'Nazirpur'),
  (244, 32, 'Kawkhali'),
  (245, 32, 'Zianagar'),
  (246, 32, 'Bhandaria'),
  (247, 32, 'Mathbaria'),
  (248, 32, 'Nesarabad'),
  (249, 33, 'Barisal Sadar'),
  (250, 33, 'Bakerganj'),
  (251, 33, 'Babuganj'),
  (252, 33, 'Wazirpur'),
  (253, 33, 'Banaripara'),
  (254, 33, 'Gournadi'),
  (255, 33, 'Agailjhara'),
  (256, 33, 'Mehendiganj'),
  (257, 33, 'Muladi'),
  (258, 33, 'Hizla'),
  (259, 34, 'Bhola Sadar'),
  (260, 34, 'Borhan Sddin'),
  (261, 34, 'Charfesson'),
  (262, 34, 'Doulatkhan'),
  (263, 34, 'Monpura'),
  (264, 34, 'Tazumuddin'),
  (265, 34, 'Lalmohan'),
  (266, 35, 'Amtali'),
  (267, 35, 'Barguna Sadar'),
  (268, 35, 'Betagi'),
  (269, 35, 'Bamna'),
  (270, 35, 'Pathorghata'),
  (271, 35, 'Taltali'),
  (272, 36, 'Balaganj'),
  (273, 36, 'Beanibazar'),
  (274, 36, 'Bishwanath'),
  (275, 36, 'Companiganj'),
  (276, 36, 'Fenchuganj'),
  (277, 36, 'Golapganj'),
  (278, 36, 'Gowainghat'),
  (279, 36, 'Jaintiapur'),
  (280, 36, 'Kanaighat'),
  (281, 36, 'Sylhet Sadar'),
  (282, 36, 'Zakiganj'),
  (283, 36, 'Dakshinsurma'),
  (284, 36, 'Osmaninagar'),
  (285, 37, 'Barlekha'),
  (286, 37, 'Kamolganj'),
  (287, 37, 'Kulaura'),
  (288, 37, 'Moulvibazar Sadar'),
  (289, 37, 'Rajnagar'),
  (290, 37, 'Sreemangal'),
  (291, 37, 'Juri'),
  (292, 38, 'Nabiganj'),
  (293, 38, 'Bahubal'),
  (294, 38, 'Ajmiriganj'),
  (295, 38, 'Baniachong'),
  (296, 38, 'Lakhai'),
  (297, 38, 'Chunarughat'),
  (298, 38, 'Habiganj Sadar'),
  (299, 38, 'Madhabpur'),
  (300, 39, 'Sunamganj Sadar'),
  (301, 39, 'South Sunamganj'),
  (302, 39, 'Bishwambarpur'),
  (303, 39, 'Chhatak'),
  (304, 39, 'Jagannathpur'),
  (305, 39, 'Dowarabazar'),
  (306, 39, 'Tahirpur'),
  (307, 39, 'Dharmapasha'),
  (308, 39, 'Jamalganj'),
  (309, 39, 'Shalla'),
  (310, 39, 'Derai'),
  (311, 40, 'Belabo'),
  (312, 40, 'Monohardi'),
  (313, 40, 'Narsingdi Sadar'),
  (314, 40, 'Palash'),
  (315, 40, 'Raipura'),
  (316, 40, 'Shibpur'),
  (317, 41, 'Kaliganj'),
  (318, 41, 'Kaliakair'),
  (319, 41, 'Kapasia'),
  (320, 41, 'Gazipur Sadar'),
  (321, 41, 'Sreepur'),
  (322, 42, 'Shariatpur Sadar'),
  (323, 42, 'Naria'),
  (324, 42, 'Zajira'),
  (325, 42, 'Gosairhat'),
  (326, 42, 'Bhedarganj'),
  (327, 42, 'Damudya'),
  (328, 43, 'Araihazar'),
  (329, 43, 'Bandar'),
  (330, 43, 'Narayanganj Sadar'),
  (331, 43, 'Rupganj'),
  (332, 43, 'Sonargaon'),
  (333, 44, 'Basail'),
  (334, 44, 'Bhuapur'),
  (335, 44, 'Delduar'),
  (336, 44, 'Ghatail'),
  (337, 44, 'Gopalpur'),
  (338, 44, 'Madhupur'),
  (339, 44, 'Mirzapur'),
  (340, 44, 'Nagarpur'),
  (341, 44, 'Sakhipur'),
  (342, 44, 'Tangail Sadar'),
  (343, 44, 'Kalihati'),
  (344, 44, 'Dhanbari'),
  (345, 45, 'Itna'),
  (346, 45, 'Katiadi'),
  (347, 45, 'Bhairab'),
  (348, 45, 'Tarail'),
  (349, 45, 'Hossainpur'),
  (350, 45, 'Pakundia'),
  (351, 45, 'Kuliarchar'),
  (352, 45, 'Kishoreganj Sadar'),
  (353, 45, 'Karimgonj'),
  (354, 45, 'Bajitpur'),
  (355, 45, 'Austagram'),
  (356, 45, 'Mithamoin'),
  (357, 45, 'Nikli'),
  (358, 46, 'Harirampur'),
  (359, 46, 'Saturia'),
  (360, 46, 'Manikganj Sadar'),
  (361, 46, 'Gior'),
  (362, 46, 'Shibaloy'),
  (363, 46, 'Doulatpur'),
  (364, 46, 'Singiar'),
  (365, 47, 'Savar'),
  (366, 47, 'Dhamrai'),
  (367, 47, 'Keraniganj'),
  (368, 47, 'Nawabganj'),
  (369, 47, 'Dohar'),
  (370, 48, 'Munshiganj Sadar'),
  (371, 48, 'Sreenagar'),
  (372, 48, 'Sirajdikhan'),
  (373, 48, 'Louhajanj'),
  (374, 48, 'Gajaria'),
  (375, 48, 'Tongibari'),
  (376, 49, 'Rajbari Sadar'),
  (377, 49, 'Goalanda'),
  (378, 49, 'Pangsa'),
  (379, 49, 'Baliakandi'),
  (380, 49, 'Kalukhali'),
  (381, 50, 'Madaripur Sadar'),
  (382, 50, 'Shibchar'),
  (383, 50, 'Kalkini'),
  (384, 50, 'Rajoir'),
  (385, 51, 'Gopalganj Sadar'),
  (386, 51, 'Kashiani'),
  (387, 51, 'Tungipara'),
  (388, 51, 'Kotalipara'),
  (389, 51, 'Muksudpur'),
  (390, 52, 'Faridpur Sadar'),
  (391, 52, 'Alfadanga'),
  (392, 52, 'Boalmari'),
  (393, 52, 'Sadarpur'),
  (394, 52, 'Nagarkanda'),
  (395, 52, 'Bhanga'),
  (396, 52, 'Charbhadrasan'),
  (397, 52, 'Madhukhali'),
  (398, 52, 'Saltha'),
  (399, 53, 'Panchagarh Sadar'),
  (400, 53, 'Debiganj'),
  (401, 53, 'Boda'),
  (402, 53, 'Atwari'),
  (403, 53, 'Tetulia'),
  (404, 54, 'Nawabganj'),
  (405, 54, 'Birganj'),
  (406, 54, 'Ghoraghat'),
  (407, 54, 'Birampur'),
  (408, 54, 'Parbatipur'),
  (409, 54, 'Bochaganj'),
  (410, 54, 'Kaharol'),
  (411, 54, 'Fulbari'),
  (412, 54, 'Dinajpur Sadar'),
  (413, 54, 'Hakimpur'),
  (414, 54, 'Khansama'),
  (415, 54, 'Birol'),
  (416, 54, 'Chirirbandar'),
  (417, 55, 'Lalmonirhat Sadar'),
  (418, 55, 'Kaliganj'),
  (419, 55, 'Hatibandha'),
  (420, 55, 'Patgram'),
  (421, 55, 'Aditmari'),
  (422, 56, 'Syedpur'),
  (423, 56, 'Domar'),
  (424, 56, 'Dimla'),
  (425, 56, 'Jaldhaka'),
  (426, 56, 'Kishorganj'),
  (427, 56, 'Nilphamari Sadar'),
  (428, 57, 'Sadullapur'),
  (429, 57, 'Gaibandha Sadar'),
  (430, 57, 'Palashbari'),
  (431, 57, 'Saghata'),
  (432, 57, 'Gobindaganj'),
  (433, 57, 'Sundarganj'),
  (434, 57, 'Phulchari'),
  (435, 58, 'Thakurgaon Sadar'),
  (436, 58, 'Pirganj'),
  (437, 58, 'Ranisankail'),
  (438, 58, 'Haripur'),
  (439, 58, 'Baliadangi'),
  (440, 59, 'Rangpur Sadar'),
  (441, 59, 'Gangachara'),
  (442, 59, 'Taragonj'),
  (443, 59, 'Badargonj'),
  (444, 59, 'Mithapukur'),
  (445, 59, 'Pirgonj'),
  (446, 59, 'Kaunia'),
  (447, 59, 'Pirgacha'),
  (448, 60, 'Kurigram Sadar'),
  (449, 60, 'Nageshwari'),
  (450, 60, 'Bhurungamari'),
  (451, 60, 'Phulbari'),
  (452, 60, 'Rajarhat'),
  (453, 60, 'Ulipur'),
  (454, 60, 'Chilmari'),
  (455, 60, 'Rowmari'),
  (456, 60, 'Charrajibpur'),
  (457, 61, 'Sherpur Sadar'),
  (458, 61, 'Nalitabari'),
  (459, 61, 'Sreebordi'),
  (460, 61, 'Nokla'),
  (461, 61, 'Jhenaigati'),
  (462, 62, 'Fulbaria'),
  (463, 62, 'Trishal'),
  (464, 62, 'Bhaluka'),
  (465, 62, 'Muktagacha'),
  (466, 62, 'Mymensingh Sadar'),
  (467, 62, 'Dhobaura'),
  (468, 62, 'Phulpur'),
  (469, 62, 'Haluaghat'),
  (470, 62, 'Gouripur'),
  (471, 62, 'Gafargaon'),
  (472, 62, 'Iswarganj'),
  (473, 62, 'Nandail'),
  (474, 62, 'Tarakanda'),
  (475, 63, 'Jamalpur Sadar'),
  (476, 63, 'Melandah'),
  (477, 63, 'Islampur'),
  (478, 63, 'Dewangonj'),
  (479, 63, 'Sarishabari'),
  (480, 63, 'Madarganj'),
  (481, 63, 'Bokshiganj'),
  (482, 64, 'Barhatta'),
  (483, 64, 'Durgapur'),
  (484, 64, 'Kendua'),
  (485, 64, 'Atpara'),
  (486, 64, 'Madan'),
  (487, 64, 'Khaliajuri'),
  (488, 64, 'Kalmakanda'),
  (489, 64, 'Mohongonj'),
  (490, 64, 'Purbadhala'),
  (491, 64, 'Netrokona Sadar'),
  (492, 9, 'Eidgaon'),
  (493, 39, 'Madhyanagar'),
  (494, 50, 'Dasar')
ON CONFLICT ("id") DO NOTHING;

-- Explicit ids above: move the sequences past them so new rows get fresh ids.
SELECT setval(pg_get_serial_sequence('"divisions"', 'id'), (SELECT MAX("id") FROM "divisions"));
SELECT setval(pg_get_serial_sequence('"districts"', 'id'), (SELECT MAX("id") FROM "districts"));
SELECT setval(pg_get_serial_sequence('"upazilas"', 'id'), (SELECT MAX("id") FROM "upazilas"));

INSERT INTO "genders" ("name") VALUES
  ('Male'),
  ('Female'),
  ('Other')
ON CONFLICT ("name") DO NOTHING;

INSERT INTO "doctor_specialties" ("name") VALUES
  ('Medicine'),
  ('Cardiology'),
  ('Gastroenterology & Hepatology'),
  ('Neurology'),
  ('Nephrology'),
  ('Endocrinology & Diabetes'),
  ('Respiratory Medicine (Chest)'),
  ('Rheumatology'),
  ('Oncology'),
  ('Haematology'),
  ('Dermatology'),
  ('Psychiatry'),
  ('Paediatrics'),
  ('Gynaecology & Obstetrics'),
  ('General Surgery'),
  ('Orthopaedics'),
  ('Neurosurgery'),
  ('Urology'),
  ('ENT'),
  ('Ophthalmology'),
  ('Dentistry'),
  ('Physical Medicine & Rehabilitation'),
  ('General Practice'),
  ('Nutrition & Dietetics')
ON CONFLICT ("name") DO NOTHING;

INSERT INTO "medicine_forms" ("name") VALUES
  ('Tablet'),
  ('Capsule'),
  ('Syrup'),
  ('Suspension'),
  ('Drops'),
  ('Injection'),
  ('Inhaler'),
  ('Cream'),
  ('Ointment'),
  ('Gel'),
  ('Suppository'),
  ('Powder'),
  ('Sachet'),
  ('Spray'),
  ('Solution')
ON CONFLICT ("name") DO NOTHING;

INSERT INTO "medicine_categories" ("name") VALUES
  ('Analgesic & Antipyretic'),
  ('Antibiotic'),
  ('Antihypertensive'),
  ('Antidiabetic'),
  ('Antacid & Anti-ulcer'),
  ('Antihistamine'),
  ('Vitamin & Supplement'),
  ('Cardiovascular'),
  ('Cholesterol-lowering'),
  ('Respiratory'),
  ('Antifungal'),
  ('Antiviral'),
  ('Anti-inflammatory'),
  ('Neurological'),
  ('Psychiatric'),
  ('Hormonal'),
  ('Dermatological'),
  ('Other')
ON CONFLICT ("name") DO NOTHING;

INSERT INTO "meal_timings" ("name") VALUES
  ('Before meal'),
  ('After meal'),
  ('With meal'),
  ('Empty stomach'),
  ('Bedtime'),
  ('Any time')
ON CONFLICT ("name") DO NOTHING;

INSERT INTO "test_categories" ("name") VALUES
  ('Blood test'),
  ('Urine test'),
  ('Stool test'),
  ('Imaging'),
  ('Cardiac'),
  ('Other')
ON CONFLICT ("name") DO NOTHING;


-- ===== prisma/pending-sql/004_round5_search_indexes.sql =====
-- Round 5: prefix-search indexes for the pharmacist autosuggest
-- (CatalogService.searchDoctors / searchMedicines / searchTests), which query
-- `lower(column) LIKE 'text%'`. Prisma's schema can't express expression
-- indexes, so they live only here (like the Round 4 CHECK constraints).
-- text_pattern_ops lets LIKE 'prefix%' use the index under any collation.
-- No schema.prisma change this round. Safe to re-run.

CREATE INDEX IF NOT EXISTS "doctors_name_prefix_idx"
  ON "doctors" (lower("name") text_pattern_ops);

CREATE INDEX IF NOT EXISTS "medicines_brandName_prefix_idx"
  ON "medicines" (lower("brandName") text_pattern_ops);

CREATE INDEX IF NOT EXISTS "medicines_genericName_prefix_idx"
  ON "medicines" (lower("genericName") text_pattern_ops);

CREATE INDEX IF NOT EXISTS "diagnostic_tests_name_prefix_idx"
  ON "diagnostic_tests" (lower("name") text_pattern_ops);


-- ===== prisma/pending-sql/005_round6_caregiver.sql =====
-- Round 6: the family OWNER role becomes CAREGIVER, and we record who acted
-- (the patient or their caregiver) on uploads, confirmations and self-added
-- routines. (Doses are marked taken by the patient only.)

-- Rename in place: existing OWNER rows become CAREGIVER (Prisma's generated
-- drop/recreate would fail casting 'OWNER').
ALTER TYPE "FamilyRole" RENAME VALUE 'OWNER' TO 'CAREGIVER';

-- AlterTable
ALTER TABLE "prescriptions" ADD COLUMN     "confirmedAt" TIMESTAMP(3),
ADD COLUMN     "confirmedById" UUID,
ADD COLUMN     "uploadedById" UUID;

-- AlterTable
ALTER TABLE "medicine_routines" ADD COLUMN     "createdById" UUID;

-- AddForeignKey
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_confirmedById_fkey" FOREIGN KEY ("confirmedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_routines" ADD CONSTRAINT "medicine_routines_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;



-- ===== prisma/pending-sql/006_round7_notice_review_note.sql =====
-- Round 7: an admin sending a pharmacist's notice back to draft leaves a
-- note for the pharmacist.

-- AlterTable
ALTER TABLE "notices" ADD COLUMN     "reviewNote" TEXT;


-- ===== prisma/pending-sql/007_generic_names.sql =====
-- Generic names move from free text (medicines.genericName) into their own
-- table, medicine_generics, linked by medicines.genericId. Pharmacists pick a
-- generic or type a new one (CatalogService.findOrCreateGeneric). Existing
-- text is copied over before the old column is dropped (nothing to copy on a
-- fresh database). Run once, in one transaction.

BEGIN;

-- CreateTable
CREATE TABLE "medicine_generics" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "medicine_generics_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "medicine_generics_name_key" ON "medicine_generics"("name");

-- Not in schema.prisma (expression index): one generic per name ignoring
-- case, and the prefix autosuggest (lower(name) LIKE 'x%', like SQL 004).
CREATE UNIQUE INDEX "medicine_generics_name_lower_key"
  ON "medicine_generics" (lower("name") text_pattern_ops);

-- AlterTable
ALTER TABLE "medicines" ADD COLUMN "genericId" INTEGER;

-- CreateIndex
CREATE INDEX "medicines_genericId_idx" ON "medicines"("genericId");

-- AddForeignKey
ALTER TABLE "medicines" ADD CONSTRAINT "medicines_genericId_fkey" FOREIGN KEY ("genericId") REFERENCES "medicine_generics"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Data: one generic per distinct name (ignoring case and spaces at the
-- ends; the earliest spelling wins), then link each medicine to it.
INSERT INTO "medicine_generics" ("name")
  SELECT DISTINCT ON (lower(trim("genericName"))) trim("genericName")
  FROM "medicines"
  WHERE trim(coalesce("genericName", '')) <> ''
  ORDER BY lower(trim("genericName")), "createdAt", "id";

UPDATE "medicines" m SET "genericId" = g."id"
  FROM "medicine_generics" g
  WHERE trim(coalesce(m."genericName", '')) <> ''
    AND lower(trim(m."genericName")) = lower(g."name");

-- DropIndex (the plain one from Round 4 and the prefix one from SQL 004)
DROP INDEX IF EXISTS "medicines_genericName_prefix_idx";
DROP INDEX IF EXISTS "medicines_genericName_idx";

-- AlterTable
ALTER TABLE "medicines" DROP COLUMN "genericName";

COMMIT;

