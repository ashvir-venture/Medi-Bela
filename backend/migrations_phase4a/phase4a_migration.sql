-- CreateEnum
CREATE TYPE "PushStatus" AS ENUM ('PENDING', 'SENT', 'FAILED', 'SKIPPED');

-- CreateEnum
CREATE TYPE "DevicePlatform" AS ENUM ('ANDROID', 'IOS');

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'PRESCRIPTION_UPDATE';

-- DropIndex
DROP INDEX "family_members_userId_idx";

-- AlterTable
ALTER TABLE "medicine_doses" ADD COLUMN     "familyAlertProcessedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "data" JSONB,
ADD COLUMN     "pushAttempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "pushStatus" "PushStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "pushedAt" TIMESTAMP(3);

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
CREATE INDEX "medicine_doses_status_scheduledAt_idx" ON "medicine_doses"("status", "scheduledAt");

-- CreateIndex
CREATE INDEX "notifications_pushStatus_createdAt_idx" ON "notifications"("pushStatus", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_userId_type_relatedEntityId_key" ON "notifications"("userId", "type", "relatedEntityId");

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Stage 4C: idempotent offline upload of health records
ALTER TABLE "health_records" ADD COLUMN IF NOT EXISTS "clientId" UUID;
CREATE UNIQUE INDEX IF NOT EXISTS "health_records_userId_clientId_key" ON "health_records"("userId", "clientId");
