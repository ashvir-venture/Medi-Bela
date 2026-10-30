-- Round 10: account lifecycle (deactivate / delete / ban) and the family
-- activity feed. Additive only: a new enum value and table, new nullable
-- columns, and two NOT NULL constraints dropped (users.phone is NULL only on
-- DELETED accounts; prescriptions.imageUrl is NULL once the photo is erased).
-- No existing rows change.

-- CreateEnum
CREATE TYPE "FamilyEventKind" AS ENUM ('CREATED', 'JOINED', 'LEFT', 'REMOVED', 'CAREGIVER_CHANGED');

-- AlterEnum
ALTER TYPE "AccountStatus" ADD VALUE 'DEACTIVATED';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "birthYear" INTEGER,
ADD COLUMN     "deactivatedAt" TIMESTAMP(3),
ADD COLUMN     "deletedAt" TIMESTAMP(3),
ADD COLUMN     "suspendedAt" TIMESTAMP(3),
ALTER COLUMN "phone" DROP NOT NULL;

-- AlterTable
ALTER TABLE "prescriptions" ALTER COLUMN "imageUrl" DROP NOT NULL;

-- CreateTable
CREATE TABLE "family_events" (
    "id" UUID NOT NULL,
    "familyId" UUID NOT NULL,
    "kind" "FamilyEventKind" NOT NULL,
    "subjectUserId" UUID,
    "actorUserId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "family_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "family_events_familyId_createdAt_id_idx" ON "family_events"("familyId", "createdAt", "id");

-- AddForeignKey
ALTER TABLE "family_events" ADD CONSTRAINT "family_events_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_events" ADD CONSTRAINT "family_events_subjectUserId_fkey" FOREIGN KEY ("subjectUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_events" ADD CONSTRAINT "family_events_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
