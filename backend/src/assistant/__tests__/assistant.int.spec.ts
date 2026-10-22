import { AssistantService, MAX_USER_MESSAGES } from '../assistant.service';
import { makeTestPrisma, makeUser, resetDb } from '../../test-utils/test-prisma';

/**
 * Real-Postgres checks for the guarantees the unit tests can only simulate:
 * row-lock based limit/idempotency, cascade delete, ownership.
 * Runs only when TEST_DATABASE_URL points at a disposable database (see test-prisma.ts).
 */
const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;
const KEY = (i: number) => `22222222-2222-4222-8222-${String(i).padStart(12, '0')}`;

d('Assistant conversations (real Postgres)', () => {
  let service: AssistantService;
  let llm: { isConfigured: jest.Mock; complete: jest.Mock };

  beforeAll(async () => {
    await prisma.$connect();
  });
  afterAll(async () => {
    await prisma.$disconnect();
  });
  beforeEach(async () => {
    await resetDb(prisma);
    llm = { isConfigured: jest.fn(() => true), complete: jest.fn(async () => 'a reply') };
    service = new AssistantService(prisma, llm as any); // fresh in-memory rate limiter per test
  });

  const send = (userId: string, cid: string, i: number, message = `q${i}`) =>
    service.sendMessage(userId, cid, { message, clientMessageId: KEY(i) } as any);
  const rows = (cid: string) => prisma.assistantMessage.findMany({ where: { conversationId: cid }, orderBy: { seq: 'asc' } });

  it('persists every message in order and reloads it; the 10th answered message closes the conversation', async () => {
    const u = await makeUser(prisma, 'U');
    const { id } = await service.createConversation(u.id);
    for (let i = 1; i <= MAX_USER_MESSAGES; i++) await send(u.id, id, i);
    const m = await rows(id);
    expect(m.map((r: any) => r.seq)).toEqual(Array.from({ length: 20 }, (_, i) => i + 1));
    expect(m.map((r: any) => r.role)).toEqual(Array.from({ length: 20 }, (_, i) => (i % 2 ? 'ASSISTANT' : 'USER')));
    await expect(send(u.id, id, 11)).rejects.toMatchObject({ status: 409 });
    const c = await service.getConversation(u.id, id);
    expect(c.status).toBe('CLOSED');
    expect(c.messages).toHaveLength(20);
  });

  it('concurrent sends with distinct keys never exceed the limit or duplicate/misorder rows', async () => {
    const u = await makeUser(prisma, 'U');
    const { id } = await service.createConversation(u.id);
    for (let wave = 0; wave < 3; wave++) {
      await Promise.allSettled(Array.from({ length: 6 }, (_, k) => send(u.id, id, wave * 6 + k + 1)));
    }
    const m = await rows(id);
    const users = m.filter((r: any) => r.role === 'USER').length;
    expect(users).toBeLessThanOrEqual(MAX_USER_MESSAGES);
    expect(m.length - users).toBeLessThanOrEqual(users); // never more replies than questions
    expect(m.map((r: any) => r.seq)).toEqual(m.map((_: any, i: number) => i + 1));
    const conv = await prisma.assistantConversation.findUnique({ where: { id } });
    expect(conv.userMessageCount).toBe(users);
  });

  it('simultaneous duplicate submissions of one message store one user row and at most one reply', async () => {
    const u = await makeUser(prisma, 'U');
    const { id } = await service.createConversation(u.id);
    await Promise.allSettled([1, 2, 3, 4, 5].map(() => send(u.id, id, 1, 'same message')));
    await send(u.id, id, 1, 'same message'); // a later retry returns the stored reply
    const m = await rows(id);
    expect(m.map((r: any) => r.role)).toEqual(['USER', 'ASSISTANT']);
    expect(llm.complete).toHaveBeenCalledTimes(1);
  });

  it('DELETE removes the conversation and its messages, even racing with in-flight sends', async () => {
    const u = await makeUser(prisma, 'U');
    const { id } = await service.createConversation(u.id);
    await send(u.id, id, 1);
    await Promise.allSettled([send(u.id, id, 2), send(u.id, id, 3), service.deleteConversation(u.id, id), send(u.id, id, 4)]);
    expect(await prisma.assistantConversation.count({ where: { id } })).toBe(0);
    expect(await prisma.assistantMessage.count({ where: { conversationId: id } })).toBe(0);
    await expect(service.deleteConversation(u.id, id)).rejects.toMatchObject({ status: 404 });
  });

  it("users cannot read, write to or delete each other's conversations; their own are unaffected", async () => {
    const a = await makeUser(prisma, 'A');
    const b = await makeUser(prisma, 'B');
    const { id } = await service.createConversation(a.id);
    await send(a.id, id, 1);
    await expect(service.getConversation(b.id, id)).rejects.toMatchObject({ status: 404 });
    await expect(send(b.id, id, 2)).rejects.toMatchObject({ status: 404 });
    await expect(service.deleteConversation(b.id, id)).rejects.toMatchObject({ status: 404 });
    expect(await rows(id)).toHaveLength(2);
    expect(await service.listConversations(b.id)).toEqual([]);
  });

  it('deleting a user removes their conversations and messages', async () => {
    const u = await makeUser(prisma, 'U');
    const { id } = await service.createConversation(u.id);
    await send(u.id, id, 1);
    await prisma.user.delete({ where: { id: u.id } });
    expect(await prisma.assistantConversation.count()).toBe(0);
    expect(await prisma.assistantMessage.count()).toBe(0);
  });
});
