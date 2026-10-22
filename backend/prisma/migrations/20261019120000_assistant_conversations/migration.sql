-- CreateEnum
CREATE TYPE "AssistantConversationStatus" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "AssistantMessageRole" AS ENUM ('USER', 'ASSISTANT');

-- CreateTable
CREATE TABLE "assistant_conversations" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "status" "AssistantConversationStatus" NOT NULL DEFAULT 'OPEN',
    "userMessageCount" INTEGER NOT NULL DEFAULT 0,
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "assistant_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "assistant_messages" (
    "id" UUID NOT NULL,
    "conversationId" UUID NOT NULL,
    "seq" INTEGER NOT NULL,
    "role" "AssistantMessageRole" NOT NULL,
    "content" TEXT NOT NULL,
    "kind" TEXT,
    "language" "Language",
    "clientMessageId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "assistant_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "assistant_conversations_userId_updatedAt_idx" ON "assistant_conversations"("userId", "updatedAt");

-- CreateIndex
CREATE UNIQUE INDEX "assistant_messages_conversationId_seq_key" ON "assistant_messages"("conversationId", "seq");

-- CreateIndex
CREATE UNIQUE INDEX "assistant_messages_conversationId_clientMessageId_key" ON "assistant_messages"("conversationId", "clientMessageId");

-- AddForeignKey
ALTER TABLE "assistant_conversations" ADD CONSTRAINT "assistant_conversations_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "assistant_messages" ADD CONSTRAINT "assistant_messages_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "assistant_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Database-level backstop for the 10-user-message limit (Prisma does not model
-- CHECK constraints; it neither manages nor drops this one). If the limit in
-- AssistantService (MAX_USER_MESSAGES) is ever changed, change this too.
ALTER TABLE "assistant_conversations"
  ADD CONSTRAINT "assistant_conversations_userMessageCount_check"
  CHECK ("userMessageCount" >= 0 AND "userMessageCount" <= 10);
