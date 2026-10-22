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
