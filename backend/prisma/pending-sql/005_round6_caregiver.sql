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

