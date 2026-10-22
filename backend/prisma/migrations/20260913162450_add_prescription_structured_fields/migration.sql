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
