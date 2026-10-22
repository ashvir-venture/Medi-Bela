import { NotFoundException } from '@nestjs/common';
import { makeTestPrisma, makeUser, resetDb, FAKE_KEY_CONFIG } from '../../test-utils/test-prisma';
import { DeviceTokensService } from '../device-tokens.service';
import { NotificationsService } from '../notifications.service';
import { TokenCryptoService } from '../token-crypto.service';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;
const TOKEN = (s: string) => `fcm-${s}-`.padEnd(40, 'x');

d('Device tokens & notification inbox (real Postgres)', () => {
  let devices: DeviceTokensService;
  let notifications: NotificationsService;
  let crypto: TokenCryptoService;
  const push = { isEnabled: () => true, send: jest.fn(async (t: string[]) => t.map((token) => ({ token, ok: true, permanentTokenFailure: false }))) } as any;

  afterAll(async () => { await prisma.$disconnect(); });
  beforeEach(async () => {
    await resetDb(prisma);
    push.send.mockClear();
    crypto = new TokenCryptoService(FAKE_KEY_CONFIG);
    devices = new DeviceTokensService(prisma, crypto);
    notifications = new NotificationsService(prisma, push, devices);
  });
  const reg = (id: string, token: string, extra = {}) => devices.register(id, { token, platform: 'ANDROID', ...extra } as any);

  describe('push token security', () => {
    it('never stores the raw token; stores keyed hash + AES-GCM ciphertext that round-trips', async () => {
      const u = await makeUser(prisma, 'U');
      await reg(u.id, TOKEN('a'));
      const rows = await prisma.$queryRawUnsafe('SELECT * FROM device_tokens');
      expect(JSON.stringify(rows)).not.toContain(TOKEN('a'));
      expect(rows[0].tokenHash).toBe(crypto.hash(TOKEN('a')));
      expect(rows[0].tokenEnc.startsWith('v1.')).toBe(true);
      expect((await devices.tokensForUsers([u.id])).get(u.id)![0].token).toBe(TOKEN('a'));
    });

    it('is tamper-evident (GCM) and uses a fresh IV each time', () => {
      const a = crypto.encrypt('same'); const b = crypto.encrypt('same');
      expect(a).not.toBe(b);
      const parts = a.split('.'); parts[3] = Buffer.from('evil').toString('base64url');
      expect(() => crypto.decrypt(parts.join('.'))).toThrow();
    });

    it('register is idempotent; refresh with previousToken swaps the old one out', async () => {
      const u = await makeUser(prisma, 'U');
      await reg(u.id, TOKEN('a')); await reg(u.id, TOKEN('a'));
      expect(await prisma.deviceToken.count()).toBe(1);
      await reg(u.id, TOKEN('b'), { previousToken: TOKEN('a') });
      expect((await devices.tokensForUsers([u.id])).get(u.id)!.map((t) => t.token)).toEqual([TOKEN('b')]);
    });

    it('a shared device re-registered by another user MOVES the token (old user stops receiving)', async () => {
      const a = await makeUser(prisma, 'A'); const b = await makeUser(prisma, 'B');
      await reg(a.id, TOKEN('shared')); await reg(b.id, TOKEN('shared'));
      expect(await prisma.deviceToken.count()).toBe(1);
      const map = await devices.tokensForUsers([a.id, b.id]);
      expect(map.get(a.id)).toBeUndefined();
      expect(map.get(b.id)).toHaveLength(1);
    });

    it('you cannot unregister or retire another user\'s token', async () => {
      const a = await makeUser(prisma, 'A'); const b = await makeUser(prisma, 'B');
      await reg(a.id, TOKEN('a'));
      await devices.unregister(b.id, TOKEN('a'));
      await reg(b.id, TOKEN('b'), { previousToken: TOKEN('a') });
      expect((await devices.tokensForUsers([a.id])).get(a.id)).toHaveLength(1);
    });

    it('unregister removes own token (idempotent); per-user cap enforced; user delete cascades', async () => {
      const u = await makeUser(prisma, 'U');
      await reg(u.id, TOKEN('a'));
      await devices.unregister(u.id, TOKEN('a')); await devices.unregister(u.id, TOKEN('a'));
      expect(await prisma.deviceToken.count()).toBe(0);
      for (let i = 0; i < 8; i++) await reg(u.id, TOKEN(`t${i}`));
      expect(await prisma.deviceToken.count({ where: { userId: u.id } })).toBe(5);
      await prisma.user.delete({ where: { id: u.id } });
      expect(await prisma.deviceToken.count()).toBe(0);
    });
  });

  describe('notification duplication', () => {
    it('same (user,type,entity) is created once however often produced, and pushed once', async () => {
      const u = await makeUser(prisma, 'U');
      await reg(u.id, TOKEN('a'));
      const item = { userId: u.id, type: 'PRESCRIPTION_UPDATE', title: 't', body: 'b', relatedEntityId: 'p1' } as any;
      await Promise.all([notifications.notify([item]), notifications.notify([item]), notifications.notify([item])]);
      expect(await prisma.notification.count()).toBe(1);
      expect(push.send).toHaveBeenCalledTimes(1);
    });

    it('push data carries only routing ids', async () => {
      const u = await makeUser(prisma, 'U');
      await reg(u.id, TOKEN('a'));
      await notifications.notify([{ userId: u.id, type: 'NOTICE', title: 'T', body: 'B', relatedEntityId: 'n1', data: { noticeId: 'n1' } } as any]);
      expect(Object.keys(push.send.mock.calls[0][1].data).sort()).toEqual(['noticeId', 'notificationId', 'type']);
    });

    it('with push disabled rows are kept for the inbox and closed as SKIPPED', async () => {
      const off = new NotificationsService(prisma, { isEnabled: () => false } as any, devices);
      const u = await makeUser(prisma, 'U');
      await off.notify([{ userId: u.id, type: 'SYSTEM', title: 't', body: 'b', relatedEntityId: 'x' } as any]);
      expect((await prisma.notification.findFirst()).pushStatus).toBe('SKIPPED');
    });
  });

  describe('inbox authorization', () => {
    it('users only list/mark their own; foreign ids are 404; read-all is scoped', async () => {
      const a = await makeUser(prisma, 'A'); const b = await makeUser(prisma, 'B');
      await notifications.createMany([
        { userId: a.id, type: 'SYSTEM', title: 'a', body: 'a', relatedEntityId: '1' } as any,
        { userId: b.id, type: 'SYSTEM', title: 'b', body: 'b', relatedEntityId: '1' } as any,
      ]);
      const aList = await notifications.list(a.id);
      expect(aList.items).toHaveLength(1); expect(aList.unreadCount).toBe(1);
      const bId = (await prisma.notification.findFirst({ where: { userId: b.id } })).id;
      await expect(notifications.markRead(a.id, bId)).rejects.toThrow(NotFoundException);
      await notifications.markAllRead(a.id);
      expect((await notifications.list(a.id)).unreadCount).toBe(0);
      expect((await notifications.list(b.id)).unreadCount).toBe(1);
      await expect(notifications.markRead(a.id, aList.items[0].id)).resolves.toBeUndefined();
    });

    it('paginates newest first with a cursor', async () => {
      const u = await makeUser(prisma, 'U');
      for (let i = 0; i < 5; i++) {
        await prisma.notification.create({ data: { userId: u.id, type: 'SYSTEM', title: `n${i}`, body: 'x', relatedEntityId: `${i}`, createdAt: new Date(Date.now() - i * 1000) } });
      }
      const p1 = await notifications.list(u.id, 2);
      expect(p1.items.map((x: any) => x.title)).toEqual(['n0', 'n1']);
      const p2 = await notifications.list(u.id, 2, p1.nextCursor!);
      expect(p2.items.map((x: any) => x.title)).toEqual(['n2', 'n3']);
      const p3 = await notifications.list(u.id, 2, p2.nextCursor!);
      expect(p3.items).toHaveLength(1); expect(p3.nextCursor).toBeNull();
    });
  });
});
