-- Round 11: when the user ticked "I agree to the Privacy & terms" at sign-up
-- (proof of consent). Existing users keep NULL and are not asked again.
-- Additive only.

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "termsAcceptedAt" TIMESTAMP(3);
