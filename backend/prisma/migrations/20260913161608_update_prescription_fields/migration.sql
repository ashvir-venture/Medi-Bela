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
