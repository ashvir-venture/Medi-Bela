-- Round 13: personal health reminders (personal_reminders), the medicine box
-- (medicine_stocks: units in the box per routine at countedAt) and
-- users.medicineBoxStartedAt. Additive only.

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "medicineBoxStartedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "personal_reminders" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "scheduleTimes" TEXT NOT NULL,
    "intervalDays" INTEGER NOT NULL DEFAULT 1,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "personal_reminders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medicine_stocks" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "routineId" UUID NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "countedAt" TIMESTAMP(3) NOT NULL,
    "updatedById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "medicine_stocks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "personal_reminders_userId_active_idx" ON "personal_reminders"("userId", "active");

-- CreateIndex
CREATE UNIQUE INDEX "medicine_stocks_routineId_key" ON "medicine_stocks"("routineId");

-- CreateIndex
CREATE INDEX "medicine_stocks_userId_idx" ON "medicine_stocks"("userId");

-- AddForeignKey
ALTER TABLE "personal_reminders" ADD CONSTRAINT "personal_reminders_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "personal_reminders" ADD CONSTRAINT "personal_reminders_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_stocks" ADD CONSTRAINT "medicine_stocks_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_stocks" ADD CONSTRAINT "medicine_stocks_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "medicine_routines"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medicine_stocks" ADD CONSTRAINT "medicine_stocks_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Not expressible in schema.prisma.
ALTER TABLE "personal_reminders" ADD CONSTRAINT "personal_reminders_intervalDays_check" CHECK ("intervalDays" BETWEEN 1 AND 90);
ALTER TABLE "medicine_stocks" ADD CONSTRAINT "medicine_stocks_quantity_check" CHECK ("quantity" >= 0);
