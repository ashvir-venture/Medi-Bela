-- AlterTable
ALTER TABLE "health_suggestions" ADD COLUMN "routineId" UUID;

-- CreateIndex
CREATE INDEX "health_suggestions_routineId_createdAt_idx" ON "health_suggestions"("routineId", "createdAt");

-- AddForeignKey
ALTER TABLE "health_suggestions" ADD CONSTRAINT "health_suggestions_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "medicine_routines"("id") ON DELETE SET NULL ON UPDATE CASCADE;
