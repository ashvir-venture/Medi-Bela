-- Round 7: an admin sending a pharmacist's notice back to draft leaves a
-- note for the pharmacist.

-- AlterTable
ALTER TABLE "notices" ADD COLUMN     "reviewNote" TEXT;
