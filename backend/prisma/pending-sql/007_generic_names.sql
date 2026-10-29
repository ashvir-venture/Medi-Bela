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
