import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { makeTestPrisma, makeUser, resetDb, FAKE_KEY_CONFIG } from '../../test-utils/test-prisma';
import { FamilyService } from '../family.service';
import { appDayBounds } from '../../common/utils/time.util';
import { NotificationsService } from '../../notifications/notifications.service';
import { DeviceTokensService } from '../../notifications/device-tokens.service';
import { TokenCryptoService } from '../../notifications/token-crypto.service';

const prisma = makeTestPrisma();
const d = prisma ? describe : describe.skip;

d('FamilyService (real Postgres)', () => {
  let svc: FamilyService;
  const push = { isEnabled: () => false, send: jest.fn() } as any;

  beforeAll(() => { delete process.env.DOSE_MISSED_GRACE_MINUTES; });
  afterAll(async () => { await prisma.$disconnect(); });
  beforeEach(async () => {
    await resetDb(prisma);
    const devices = new DeviceTokensService(prisma, new TokenCryptoService(FAKE_KEY_CONFIG));
    svc = new FamilyService(prisma, new NotificationsService(prisma, push, devices));
  });

  const invite = (owner: any, phone: string) => svc.inviteMember(owner.id, { phone } as any);

  async function familyOf(ownerName = 'Owner') {
    const owner = await makeUser(prisma, ownerName, { address: 'Owner Street 1' });
    const fam = await svc.createFamily(owner.id, {} as any);
    return { owner, fam };
  }
  async function join(owner: any, member: any) {
    const inv = await invite(owner, member.phone);
    await svc.acceptInvitation(member.id, member.phone, inv.id);
  }

  describe('creation & membership', () => {
    it('one family per user — concurrent creates yield exactly one', async () => {
      const u = await makeUser(prisma, 'U');
      const results = await Promise.allSettled([1, 2, 3].map(() => svc.createFamily(u.id, {} as any)));
      expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      expect(results.filter((r) => r.status === 'rejected').every((r: any) => r.reason instanceof ConflictException)).toBe(true);
      expect(await prisma.familyMember.count({ where: { userId: u.id } })).toBe(1);
    });

    it('response never contains password/refresh hashes or the privacy flag', async () => {
      const { fam } = await familyOf();
      expect(JSON.stringify(fam)).not.toMatch(/passwordHash|hashedRefreshToken|profileVisibleToFamily/);
    });

    it('hides a member address that opted out — in BOTH /family and /family/members', async () => {
      const { owner } = await familyOf();
      const m = await makeUser(prisma, 'M', { address: 'Secret Lane', profileVisibleToFamily: false });
      await join(owner, m);
      expect(JSON.stringify(await svc.getMyFamily(owner.id))).not.toContain('Secret Lane');
      const viaMembers = JSON.stringify(await svc.listMembers(owner.id));
      expect(viaMembers).not.toContain('Secret Lane');
      expect(viaMembers).toContain('Owner Street 1');
    });

    it('a non-member sees "not in a family", never another family', async () => {
      await familyOf();
      const stranger = await makeUser(prisma, 'Stranger');
      await expect(svc.getMyFamily(stranger.id)).rejects.toThrow(NotFoundException);
      await expect(svc.listMembers(stranger.id)).rejects.toThrow(NotFoundException);
    });
  });

  describe('invitations', () => {
    it('invitee matching is phone-format independent (local 01… vs +880…)', async () => {
      const { owner } = await familyOf();
      const m = await prisma.user.create({ data: { phone: '+8801711111111', name: 'Local', passwordHash: 'x' } });
      await svc.inviteMember(owner.id, { phone: '01711111111' } as any);
      expect(await svc.listIncomingInvitations(m.phone)).toHaveLength(1);
    });

    it('incoming invitation reveals inviter NAME only (no phone/address) to a non-member', async () => {
      const { owner } = await familyOf();
      const m = await makeUser(prisma, 'Invitee');
      await invite(owner, m.phone);
      const [inv] = await svc.listIncomingInvitations(m.phone);
      expect(inv.invitedBy).toEqual({ name: 'Owner' });
      expect(JSON.stringify(inv)).not.toContain('Street');
      expect(JSON.stringify(inv.invitedBy)).not.toContain(owner.phone);
    });

    it('response is identical in shape for registered and unregistered numbers (no enumeration oracle)', async () => {
      const { owner } = await familyOf();
      const reg = await makeUser(prisma, 'Reg');
      const a = await invite(owner, reg.phone);
      const b = await invite(owner, '+8801899999999');
      expect(Object.keys(a).sort()).toEqual(Object.keys(b).sort());
    });

    it('only the owner can invite or list sent invitations', async () => {
      const { owner } = await familyOf();
      const m = await makeUser(prisma, 'M'); await join(owner, m);
      await expect(invite(m, '+8801811111111')).rejects.toThrow(ForbiddenException);
      await expect(svc.listSentInvitations(m.id)).rejects.toThrow(ForbiddenException);
    });

    it('cannot invite self, an existing member, or the same pending number twice (even concurrently)', async () => {
      const { owner } = await familyOf();
      const m = await makeUser(prisma, 'M'); await join(owner, m);
      await expect(invite(owner, owner.phone)).rejects.toThrow();
      await expect(invite(owner, m.phone)).rejects.toThrow(ConflictException);
      const res = await Promise.allSettled([1, 2, 3].map(() => invite(owner, '+8801822222222')));
      expect(res.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      expect(await prisma.familyInvitation.count({ where: { invitedPhone: '+8801822222222' } })).toBe(1);
    });

    it('an EXPIRED pending invitation does not block re-inviting the same number', async () => {
      const { owner } = await familyOf();
      const inv = await invite(owner, '+8801833333333');
      await prisma.familyInvitation.update({ where: { id: inv.id }, data: { expiresAt: new Date(Date.now() - 1000) } });
      await expect(invite(owner, '+8801833333333')).resolves.toBeDefined();
    });

    it('only the addressed phone can accept/decline; others get 404 (IDOR)', async () => {
      const { owner } = await familyOf();
      const target = await makeUser(prisma, 'Target');
      const other = await makeUser(prisma, 'Other');
      const inv = await invite(owner, target.phone);
      await expect(svc.acceptInvitation(other.id, other.phone, inv.id)).rejects.toThrow(NotFoundException);
      await expect(svc.declineInvitation(other.phone, inv.id)).rejects.toThrow(NotFoundException);
      expect(await prisma.familyMember.count({ where: { userId: other.id } })).toBe(0);
    });

    it('accept is single-use and race-safe; declined/expired cannot be accepted', async () => {
      const { owner } = await familyOf();
      const t = await makeUser(prisma, 'T');
      const inv = await invite(owner, t.phone);
      const res = await Promise.allSettled([
        svc.acceptInvitation(t.id, t.phone, inv.id), svc.acceptInvitation(t.id, t.phone, inv.id),
      ]);
      expect(res.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      expect(await prisma.familyMember.count({ where: { userId: t.id } })).toBe(1);

      const d2 = await makeUser(prisma, 'D');
      const inv2 = await invite(owner, d2.phone);
      await svc.declineInvitation(d2.phone, inv2.id);
      await expect(svc.acceptInvitation(d2.id, d2.phone, inv2.id)).rejects.toThrow(ConflictException);
      expect(await prisma.familyMember.count({ where: { userId: d2.id } })).toBe(0);

      const e = await makeUser(prisma, 'E');
      const inv3 = await invite(owner, e.phone);
      await prisma.familyInvitation.update({ where: { id: inv3.id }, data: { expiresAt: new Date(Date.now() - 1000) } });
      await expect(svc.acceptInvitation(e.id, e.phone, inv3.id)).rejects.toThrow(ConflictException);
    });

    it('a member of a real family cannot join another; a SOLE owner of an empty family can', async () => {
      const A = await familyOf('A'); const B = await familyOf('B');
      const member = await makeUser(prisma, 'Mem'); await join(A.owner, member);
      const invB = await invite(B.owner, member.phone);
      await expect(svc.acceptInvitation(member.id, member.phone, invB.id)).rejects.toThrow(ConflictException);

      const solo = await makeUser(prisma, 'Solo');
      await svc.createFamily(solo.id, {} as any);
      const invA = await invite(A.owner, solo.phone);
      await svc.acceptInvitation(solo.id, solo.phone, invA.id);
      expect((await svc.getMyFamily(solo.id)).id).toBe(A.fam.id);
      expect(await prisma.family.count()).toBe(2);
    });
  });

  describe('member medicine status — isolation & privacy', () => {
    async function withDoses(user: any, doses: Array<{ h: number; status?: string }>) {
      const r = await prisma.medicineRoutine.create({ data: { userId: user.id, medicineName: 'Metformin', dosage: '500mg', frequency: 'd', startDate: new Date() } });
      const now = Date.now();
      for (const x of doses) {
        await prisma.medicineDose.create({ data: { routineId: r.id, userId: user.id, scheduledAt: new Date(now - x.h * 3_600_000), status: x.status ?? 'PENDING' } });
      }
    }

    it('a family member sees another member\'s status (name+time+status; no dosage/ids)', async () => {
      const { owner } = await familyOf();
      const m = await makeUser(prisma, 'Mem'); await join(owner, m);
      await withDoses(m, [{ h: 0.1, status: 'TAKEN' }]);
      const res: any = await svc.getMemberStatus(owner.id, m.id);
      expect(res.shared).toBe(true);
      const json = JSON.stringify(res);
      expect(json).toContain('Metformin');
      expect(json).not.toMatch(/500mg|routineId|"id"/);
    });

    it('an OUTSIDER cannot read anyone\'s status; same 404 as a nonexistent user', async () => {
      const { owner } = await familyOf();
      const outsider = await makeUser(prisma, 'Out');
      await svc.createFamily(outsider.id, {} as any);
      await withDoses(owner, [{ h: 0.1 }]);
      await expect(svc.getMemberStatus(outsider.id, owner.id)).rejects.toThrow(NotFoundException);
      await expect(svc.getMemberStatus(outsider.id, '00000000-0000-4000-8000-000000000000')).rejects.toThrow(NotFoundException);
      const loner = await makeUser(prisma, 'Loner');
      await expect(svc.getMemberStatus(loner.id, owner.id)).rejects.toThrow(NotFoundException);
      await expect(svc.getMembersStatusSummary(loner.id)).rejects.toThrow(NotFoundException);
    });

    it('a member who stopped sharing exposes NO health data in detail or summary', async () => {
      const { owner } = await familyOf();
      const m = await makeUser(prisma, 'Mem', { profileVisibleToFamily: false }); await join(owner, m);
      await withDoses(m, [{ h: 0.1 }, { h: 5 }]);
      expect(await svc.getMemberStatus(owner.id, m.id)).toMatchObject({ shared: false, doses: [], today: null });
      const sum: any = await svc.getMembersStatusSummary(owner.id);
      expect(sum.members[0]).toEqual({ userId: m.id, name: 'Mem', shared: false });
    });

    it('summary covers only the caller\'s own family, excludes the caller, flags overdue as missed', async () => {
      const A = await familyOf('A'); const B = await familyOf('B');
      const m = await makeUser(prisma, 'Mem'); await join(A.owner, m);
      // Time-of-day independent: shrink the grace window and schedule the overdue
      // dose just after the app-timezone midnight, so it is "today" and overdue at any hour.
      process.env.DOSE_MISSED_GRACE_MINUTES = '5';
      const dayStart = appDayBounds(new Date()).start;
      const r = await prisma.medicineRoutine.create({ data: { userId: m.id, medicineName: 'X', dosage: '1', frequency: 'd', startDate: new Date() } });
      await prisma.medicineDose.create({ data: { routineId: r.id, userId: m.id, scheduledAt: new Date(dayStart.getTime() + 60_000), status: 'PENDING' } });
      await prisma.medicineDose.create({ data: { routineId: r.id, userId: m.id, scheduledAt: new Date(dayStart.getTime() + 120_000), status: 'TAKEN' } });
      const sum: any = await svc.getMembersStatusSummary(A.owner.id);
      delete process.env.DOSE_MISSED_GRACE_MINUTES;
      expect(sum.members.map((x: any) => x.userId)).toEqual([m.id]);
      expect(sum.members[0].today).toMatchObject({ taken: 1, missed: 1 });
      expect((await svc.getMembersStatusSummary(B.owner.id) as any).members).toEqual([]);
    });
  });
});
