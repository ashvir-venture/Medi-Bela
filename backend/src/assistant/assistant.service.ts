import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AssistantConversationStatus, AssistantMessageRole, Language } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  AssistantReplyKind,
  buildSystemPrompt,
  candidateBrandWords,
  clean,
  detectEmergency,
  detectRestrictedIntent,
  disclaimerFor,
  emergencyReply,
  refusalReply,
} from './assistant-safety';
import { SendMessageDto } from './dto/chat.dto';
import { ChatTurn, LlmProvider, trimToSentence } from './llm.provider';
import { ErrorCode, withCode } from '../common/filters/error-codes';

/** 503 with its own code, so the apps show a message instead of the maintenance screen. */
const assistantUnavailable = () =>
  withCode(new ServiceUnavailableException('The assistant is currently unavailable'), ErrorCode.AI_UNAVAILABLE);

/** One persisted message as returned to the client. */
export interface MessageView {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: Date;
  /** Assistant messages only. */
  kind?: AssistantReplyKind;
  disclaimer?: string;
  /** User messages only: the idempotency key to re-send when retrying an unanswered message. */
  clientMessageId?: string | null;
}

export interface ConversationSummary {
  id: string;
  status: AssistantConversationStatus;
  userMessageCount: number;
  maxUserMessages: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface ConversationListItem extends ConversationSummary {
  /** First user message, flattened and clipped; used as the list title. */
  preview: string;
}

export interface ConversationDetail extends ConversationSummary {
  messages: MessageView[];
}

export interface SendMessageResponse {
  reply: string;
  kind: AssistantReplyKind;
  /** Always present, always added by the server (never left to the model). */
  disclaimer: string;
  messageId: string;
  conversationStatus: AssistantConversationStatus;
  userMessageCount: number;
  maxUserMessages: number;
}

/** Per-user cap so the assistant can't be used to run up the AI bill. */
const MAX_MESSAGES_PER_HOUR = 20;
const WINDOW_MS = 60 * 60 * 1000;
const MAX_REPLY_CHARS = 1000; // ~120 words

/** Keep in sync with the CHECK constraint in the assistant_conversations migration. */
export const MAX_USER_MESSAGES = 10;
/** Complete user/assistant exchanges (not messages) sent to the model as context. */
export const CONTEXT_EXCHANGES = 3;
const LIST_LIMIT = 100;
const PREVIEW_CHARS = 80;

const conflict = (code: string, message: string) => new ConflictException({ message, error: code });
const notFound = () => new NotFoundException('Conversation not found');

/**
 * The last `max` COMPLETE exchanges (user message immediately followed by its
 * assistant reply) from chronologically ordered turns. A trailing user message
 * without a reply, or a stray assistant message with no user message before
 * it, is never sent as context.
 */
export function lastCompleteExchanges(turns: ChatTurn[], max: number = CONTEXT_EXCHANGES): ChatTurn[] {
  const out: ChatTurn[] = [];
  let i = turns.length - 1;
  while (i >= 0 && out.length < max * 2) {
    if (turns[i].role === 'assistant' && i > 0 && turns[i - 1].role === 'user') {
      out.unshift(turns[i - 1], turns[i]);
      i -= 2;
    } else {
      i -= 1;
    }
  }
  return out;
}

/**
 * Flutter -> NestJS (here) -> LlmProvider -> AI provider -> back.
 *
 * READ-ONLY w.r.t. medical data: the only data it ever reads for context is
 * the user's own routines and reminders (`findMany`), and its only writes are
 * to its own conversation tables. It has no write path to routines, rules,
 * prescriptions or reminders and passes the model no tools, so the assistant
 * cannot modify anything even if it is manipulated. (A test enforces this.)
 *
 * Sending a message, in three steps (no DB transaction is ever held open
 * while waiting for the model):
 *   1. short transaction: lock the conversation row, enforce ownership /
 *      open status / 10-message limit / idempotency, save the user message;
 *   2. build context from the DB and get the reply (safety rules or model);
 *   3. short transaction: lock the row again, save the reply (once), and
 *      close the conversation after the 10th user message.
 * The row lock is what makes the limit and de-duplication concurrency-safe,
 * and it also makes a concurrent DELETE wait instead of racing with a send.
 */
@Injectable()
export class AssistantService {
  private readonly recent = new Map<string, number[]>();
  /** User messages whose reply is being produced by THIS instance (avoids a second paid model call). */
  private readonly inFlight = new Set<string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly llm: LlmProvider,
  ) {}

  // ---- Conversations ------------------------------------------------------

  async createConversation(userId: string): Promise<ConversationSummary> {
    const c = await this.prisma.assistantConversation.create({ data: { userId } });
    return this.toSummary(c);
  }

  /** Newest first. Conversations that never received a message are not listed. */
  async listConversations(userId: string): Promise<ConversationListItem[]> {
    const rows = await this.prisma.assistantConversation.findMany({
      where: { userId, messages: { some: {} } },
      orderBy: { updatedAt: 'desc' },
      take: LIST_LIMIT,
      include: {
        messages: {
          where: { role: AssistantMessageRole.USER },
          orderBy: { seq: 'asc' },
          take: 1,
          select: { content: true },
        },
      },
    });
    return rows.map((c) => ({ ...this.toSummary(c), preview: clean(c.messages[0]?.content, PREVIEW_CHARS) }));
  }

  async getConversation(userId: string, conversationId: string): Promise<ConversationDetail> {
    const c = await this.prisma.assistantConversation.findFirst({
      where: { id: conversationId, userId },
      include: { messages: { orderBy: { seq: 'asc' } } },
    });
    if (!c) throw notFound();
    return { ...this.toSummary(c), messages: c.messages.map((m) => this.toMessageView(m)) };
  }

  /**
   * Hard-deletes the caller's conversation; the FK cascade removes its messages
   * in the same statement. The DELETE needs the row lock, so it waits for any
   * in-flight send transaction and a later send cannot recreate anything.
   */
  async deleteConversation(userId: string, conversationId: string): Promise<void> {
    const { count } = await this.prisma.assistantConversation.deleteMany({ where: { id: conversationId, userId } });
    if (count === 0) throw notFound();
  }

  // ---- Chat ---------------------------------------------------------------

  async sendMessage(
    userId: string,
    conversationId: string,
    dto: SendMessageDto,
    now: number = Date.now(),
  ): Promise<SendMessageResponse> {
    this.enforceRateLimit(userId, now);

    const message = dto.message.trim();
    if (!message) throw new BadRequestException('Message cannot be empty');

    // 1. Save the user message (or recognise a retry of one already saved).
    const accepted = await this.acceptUserMessage(userId, conversationId, message, dto.clientMessageId);
    if (accepted.reply) return this.toSendResponse(accepted.reply, accepted.conversation); // retry of an answered message

    const userMessage = accepted.userMessage;
    if (this.inFlight.has(userMessage.id)) {
      throw conflict('REPLY_IN_PROGRESS', 'This message is already being answered');
    }
    this.inFlight.add(userMessage.id);
    try {
      const lang = dto.language ?? (await this.languageOf(userId));
      // 2. Reply (may throw 503: the saved user message stays and can be retried).
      const generated = await this.generateReply(userId, conversationId, userMessage, lang);
      // 3. Save the reply and, after the 10th user message, close the conversation.
      const saved = await this.saveReply(userId, conversationId, userMessage.seq, generated, lang);
      return this.toSendResponse(saved.message, saved.conversation);
    } finally {
      this.inFlight.delete(userMessage.id);
    }
  }

  /** Transaction 1. Holds the conversation row lock only for a few quick queries. */
  private acceptUserMessage(userId: string, conversationId: string, message: string, clientMessageId: string) {
    return this.prisma.$transaction(async (tx) => {
      // Lock the row (and prove ownership) until this transaction ends. Every
      // other send/reply/delete for this conversation waits here.
      const locked = await tx.assistantConversation.updateMany({
        where: { id: conversationId, userId },
        data: { updatedAt: new Date() },
      });
      if (locked.count === 0) throw notFound();

      const existing = await tx.assistantMessage.findFirst({ where: { conversationId, clientMessageId } });
      if (existing) {
        // Retry of a message we already saved: never insert it or count it again.
        const reply = await tx.assistantMessage.findUnique({
          where: { conversationId_seq: { conversationId, seq: existing.seq + 1 } },
        });
        const conversation = await tx.assistantConversation.findUniqueOrThrow({ where: { id: conversationId } });
        return { userMessage: existing, reply, conversation };
      }

      const last = await tx.assistantMessage.findFirst({
        where: { conversationId },
        orderBy: { seq: 'desc' },
        select: { seq: true, role: true },
      });
      if (last?.role === AssistantMessageRole.USER) {
        throw conflict('REPLY_PENDING', 'The previous message has not been answered yet. Retry it first.');
      }

      // Atomic limit check: only an OPEN conversation below the cap takes a new message.
      const slot = await tx.assistantConversation.updateMany({
        where: {
          id: conversationId,
          userId,
          status: AssistantConversationStatus.OPEN,
          userMessageCount: { lt: MAX_USER_MESSAGES },
        },
        data: { userMessageCount: { increment: 1 } },
      });
      if (slot.count === 0) {
        throw conflict('CONVERSATION_CLOSED', 'This conversation is closed. Start a new conversation to keep chatting.');
      }

      const userMessage = await tx.assistantMessage.create({
        data: {
          conversationId,
          seq: (last?.seq ?? 0) + 1,
          role: AssistantMessageRole.USER,
          content: message,
          clientMessageId,
        },
      });
      const conversation = await tx.assistantConversation.findUniqueOrThrow({ where: { id: conversationId } });
      return { userMessage, reply: null, conversation };
    });
  }

  /** Context from the DB (never from the client) + deterministic safety + model. No transaction is open here. */
  private async generateReply(
    userId: string,
    conversationId: string,
    userMessage: { seq: number; content: string },
    lang: Language,
  ): Promise<{ content: string; kind: AssistantReplyKind }> {
    const message = userMessage.content;

    // Newest 6 messages before this one = at most 3 exchanges, restored to chronological order.
    const prior = await this.prisma.assistantMessage.findMany({
      where: { conversationId, seq: { lt: userMessage.seq }, conversation: { userId } },
      orderBy: { seq: 'desc' },
      take: CONTEXT_EXCHANGES * 2,
      select: { role: true, content: true },
    });
    const history = lastCompleteExchanges(
      prior.reverse().map((m) => ({
        role: m.role === AssistantMessageRole.USER ? ('user' as const) : ('assistant' as const),
        content: m.content,
      })),
    );

    // 1. Deterministic safety, before any model call or data lookup.
    //    The latest message AND the recent user turns are checked, so an
    //    emergency mentioned a moment ago is not lost on a follow-up.
    const userTexts = [message, ...history.filter((t) => t.role === 'user').map((t) => t.content)];
    if (userTexts.some(detectEmergency)) return { content: emergencyReply(lang), kind: 'EMERGENCY' };
    const intent = detectRestrictedIntent(message);
    if (intent) return { content: refusalReply(intent, lang), kind: 'REFUSAL' };

    // 2. Model: system prompt + (at most) the last 3 complete exchanges + the new message, once.
    if (!this.llm.isConfigured()) throw assistantUnavailable();
    const context = await this.loadContext(userId, message);
    const turns: ChatTurn[] = [...history, { role: 'user', content: message }];
    const text = await this.llm.complete(buildSystemPrompt(lang, context), turns);
    // An empty/failed completion is never stored as a reply.
    if (!text) throw assistantUnavailable();

    // Over the cap: cut back to the last whole sentence, never mid-word.
    const content = text.length > MAX_REPLY_CHARS ? trimToSentence(text.slice(0, MAX_REPLY_CHARS)) : text;
    return { content, kind: 'ANSWER' };
  }

  /** Transaction 2. Idempotent: a reply for this user message is stored at most once. */
  private saveReply(
    userId: string,
    conversationId: string,
    userSeq: number,
    reply: { content: string; kind: AssistantReplyKind },
    lang: Language,
  ) {
    return this.prisma.$transaction(async (tx) => {
      // 0 rows = the conversation was deleted while the model was thinking: store nothing.
      const locked = await tx.assistantConversation.updateMany({
        where: { id: conversationId, userId },
        data: { updatedAt: new Date() },
      });
      if (locked.count === 0) throw notFound();

      const seq = userSeq + 1;
      let message = await tx.assistantMessage.findUnique({
        where: { conversationId_seq: { conversationId, seq } },
      });
      if (!message) {
        message = await tx.assistantMessage.create({
          data: {
            conversationId,
            seq,
            role: AssistantMessageRole.ASSISTANT,
            content: reply.content,
            kind: reply.kind,
            language: lang,
          },
        });
      }
      // The 10th user message has now been answered: make the conversation read-only.
      await tx.assistantConversation.updateMany({
        where: { id: conversationId, status: AssistantConversationStatus.OPEN, userMessageCount: { gte: MAX_USER_MESSAGES } },
        data: { status: AssistantConversationStatus.CLOSED, closedAt: new Date() },
      });
      const conversation = await tx.assistantConversation.findUniqueOrThrow({ where: { id: conversationId } });
      return { message, conversation };
    });
  }

  // ---- Helpers ------------------------------------------------------------

  private toSummary(c: {
    id: string;
    status: AssistantConversationStatus;
    userMessageCount: number;
    createdAt: Date;
    updatedAt: Date;
  }): ConversationSummary {
    return {
      id: c.id,
      status: c.status,
      userMessageCount: c.userMessageCount,
      maxUserMessages: MAX_USER_MESSAGES,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    };
  }

  private toMessageView(m: {
    id: string;
    role: AssistantMessageRole;
    content: string;
    kind: string | null;
    language: Language | null;
    clientMessageId: string | null;
    createdAt: Date;
  }): MessageView {
    if (m.role === AssistantMessageRole.USER) {
      return { id: m.id, role: 'user', content: m.content, createdAt: m.createdAt, clientMessageId: m.clientMessageId };
    }
    return {
      id: m.id,
      role: 'assistant',
      content: m.content,
      createdAt: m.createdAt,
      kind: (m.kind as AssistantReplyKind) ?? 'ANSWER',
      disclaimer: disclaimerFor(m.language ?? Language.EN),
    };
  }

  private toSendResponse(
    message: { id: string; content: string; kind: string | null; language: Language | null },
    conversation: { status: AssistantConversationStatus; userMessageCount: number },
  ): SendMessageResponse {
    return {
      reply: message.content,
      kind: (message.kind as AssistantReplyKind) ?? 'ANSWER',
      disclaimer: disclaimerFor(message.language ?? Language.EN),
      messageId: message.id,
      conversationStatus: conversation.status,
      userMessageCount: conversation.userMessageCount,
      maxUserMessages: MAX_USER_MESSAGES,
    };
  }

  private async languageOf(userId: string): Promise<Language> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { languagePreference: true } });
    return user?.languagePreference ?? Language.EN;
  }

  /**
   * The user's OWN verified routine and upcoming reminders, plus catalog
   * entries for brand names in the message (so "Napa" reaches the model as
   * paracetamol). No name, phone or address.
   */
  private async loadContext(userId: string, message: string) {
    const words = candidateBrandWords(message);
    const [routines, reminders, catalog] = await Promise.all([
      this.prisma.medicineRoutine.findMany({
        where: { userId, active: true },
        orderBy: { createdAt: 'desc' },
        take: 10,
        select: {
          medicineName: true,
          dosage: true,
          frequency: true,
          prescriptionMedicine: { select: { instructions: true } },
        },
      }),
      this.prisma.healthReminder.findMany({
        where: { userId, status: 'PENDING' },
        orderBy: { scheduledAt: 'asc' },
        take: 10,
        select: { title: true, scheduledAt: true },
      }),
      words.length
        ? this.prisma.medicine.findMany({
            where: { brandName: { in: words, mode: 'insensitive' }, genericId: { not: null } },
            take: 5,
            select: { brandName: true, generic: { select: { name: true } }, form: { select: { name: true } } },
          })
        : Promise.resolve([]),
    ]);
    return {
      routines: routines.map((r: any) => ({
        medicine: clean(r.medicineName, 80),
        dosage: clean(r.dosage, 40),
        frequency: clean(r.frequency, 60),
        instructions: r.prescriptionMedicine?.instructions ? clean(r.prescriptionMedicine.instructions, 160) : null,
      })),
      reminders: reminders.map((r: any) => ({
        title: clean(r.title, 120),
        when: new Date(r.scheduledAt).toISOString().slice(0, 10),
      })),
      catalog: catalog.map((m: any) => ({
        brand: clean(m.brandName, 60),
        generic: clean(m.generic?.name, 80),
        form: m.form?.name ? clean(m.form.name, 30) : null,
      })),
    };
  }

  private enforceRateLimit(userId: string, now: number) {
    const hits = (this.recent.get(userId) ?? []).filter((t) => now - t < WINDOW_MS);
    if (hits.length >= MAX_MESSAGES_PER_HOUR) {
      this.recent.set(userId, hits);
      throw new HttpException('Too many assistant messages. Please try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    hits.push(now);
    this.recent.set(userId, hits);
  }
}
