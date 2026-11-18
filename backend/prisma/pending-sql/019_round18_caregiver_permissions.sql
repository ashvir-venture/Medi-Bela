-- Round 18 (owner, 2026-11-17): what a member lets the family caregiver do.
-- View (see) and Manage (change), both off by default; Manage implies View.
-- caregiverPermissionAt = when the member answered (NULL = ask). Additive.

-- AlterTable
ALTER TABLE "family_members" ADD COLUMN     "caregiverCanManage" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "caregiverCanView" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "caregiverPermissionAt" TIMESTAMP(3);


-- Manage includes View (the API stores both when Manage is on).
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_manage_implies_view" CHECK (NOT "caregiverCanManage" OR "caregiverCanView");
