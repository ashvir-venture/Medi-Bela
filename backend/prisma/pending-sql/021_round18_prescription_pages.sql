-- Round 18 (owner, 2026-11-17; client point 2): every page of a prescription,
-- uploaded from the phone straight to Cloudinary (imageUrl stays page 1).
-- Additive; older rows keep an empty list.

-- AlterTable
ALTER TABLE "prescriptions" ADD COLUMN     "pageUrls" TEXT[] DEFAULT ARRAY[]::TEXT[];


-- At most 5 pages (the API also checks).
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_page_count" CHECK (cardinality("pageUrls") <= 5);
