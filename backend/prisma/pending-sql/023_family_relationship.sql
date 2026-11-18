-- Owner 2026-11-18: the relationship chosen when inviting to the family
-- ("Baba", "Ma", ...), so the inviter sees "Baba" instead of the name in the
-- family list and in alerts ("Baba missed a medicine"). A lookup table
-- (EN/BN, owner-edited like conditions), the choice on the invitation, and
-- on the member (with whose word it is). Additive only; existing members
-- keep NULL (their name is shown, as before).

-- AlterTable
ALTER TABLE "family_members" ADD COLUMN     "relationToUserId" UUID,
ADD COLUMN     "relationshipId" INTEGER;

-- AlterTable
ALTER TABLE "family_invitations" ADD COLUMN     "relationshipId" INTEGER;

-- CreateTable
CREATE TABLE "relationships" (
    "id" SERIAL NOT NULL,
    "code" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameBn" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "relationships_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "relationships_code_key" ON "relationships"("code");

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_relationshipId_fkey" FOREIGN KEY ("relationshipId") REFERENCES "relationships"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_invitations" ADD CONSTRAINT "family_invitations_relationshipId_fkey" FOREIGN KEY ("relationshipId") REFERENCES "relationships"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Reference data (owner's list, 2026-11-18). Re-runnable.
INSERT INTO "relationships" ("code", "nameEn", "nameBn", "sortOrder") VALUES
  ('father',      'Father',      'বাবা',     1),
  ('mother',      'Mother',      'মা',       2),
  ('brother',     'Brother',     'ভাই',      3),
  ('sister',      'Sister',      'বোন',      4),
  ('son',         'Son',         'ছেলে',     5),
  ('daughter',    'Daughter',    'মেয়ে',     6),
  ('grandfather', 'Grandfather', 'দাদা',     7),
  ('grandmother', 'Grandmother', 'দাদি',     8),
  ('uncle',       'Uncle',       'আঙ্কেল',   9),
  ('aunt',        'Aunt',        'আন্টি',    10),
  ('other',       'Other',       'অন্যান্য', 11)
ON CONFLICT ("code") DO NOTHING;
