import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { FamilyMembershipService } from '../family-membership.service';
import { FamilyService } from '../family.service';

/** members: [{ id, userId, role }] in joinedAt order. */
function setup(members: any[]) {
  let rows = [...members];
  const events: any[] = [];
  const tx: any = {
    familyMember: {
      findUnique: jest.fn(async ({ where }: any) => {
        const m = rows.find((r) => r.userId === where.userId);
        return m ? { ...m, familyId: 'f1' } : null;
      }),
      findFirst: jest.fn(async ({ where }: any) => rows.find((r) => r.userId === where.userId) ?? null),
      delete: jest.fn(async ({ where }: any) => {
        rows = rows.filter((r) => r.id !== where.id);
      }),
      findMany: jest.fn(async () => rows.map((r) => ({ id: r.id, userId: r.userId, user: { languagePreference: 'EN' } }))),
      update: jest.fn(async ({ where, data }: any) => {
        rows = rows.map((r) => (r.id === where.id ? { ...r, ...data } : r));
      }),
    },
    familyInvitation: { deleteMany: jest.fn(async () => ({ count: 0 })) },
    family: { delete: jest.fn(async () => ({})) },
    familyEvent: { create: jest.fn(async ({ data }: any) => events.push(data)), findMany: jest.fn(async () => []) },
    user: { findUnique: jest.fn(async () => ({ name: 'Rahima', languagePreference: 'BN' })) },
  };
  tx.$transaction = async (fn: any) => fn(tx);
  const audit = { record: jest.fn(async (..._args: any[]) => undefined) };
  const notifications = { notify: jest.fn(async (..._args: any[]) => undefined) };
  const membership = new FamilyMembershipService(tx, audit as any, notifications as any);
  const family = new FamilyService(tx, notifications as any, membership);
  return { tx, audit, notifications, membership, family, events, rows: () => rows };
}

const FAMILY = [
  { id: 'm1', userId: 'care', role: 'CAREGIVER' },
  { id: 'm2', userId: 'early', role: 'MEMBER' },
  { id: 'm3', userId: 'late', role: 'MEMBER' },
];

describe('leave and caregiver handover', () => {
  it('a member leaves: LEFT event, audited, no handover, no push', async () => {
    const s = setup(FAMILY);
    await s.family.leave('late');
    expect(s.events).toEqual([{ familyId: 'f1', kind: 'LEFT', subjectUserId: 'late', actorUserId: 'late' }]);
    expect((s.audit.record.mock.calls as any[])[0][0].action).toBe('family.leave');
    expect(s.rows().find((r) => r.userId === 'early')!.role).toBe('MEMBER');
    expect(s.notifications.notify).not.toHaveBeenCalled();
  });

  it('the caregiver leaves: the earliest member becomes caregiver, CAREGIVER_CHANGED, everyone is told, pending invitations go', async () => {
    const s = setup(FAMILY);
    await s.family.leave('care');
    expect(s.rows().find((r) => r.userId === 'early')!.role).toBe('CAREGIVER');
    expect(s.events.map((e) => e.kind)).toEqual(['LEFT', 'CAREGIVER_CHANGED']);
    expect(s.events[1].subjectUserId).toBe('early');
    expect(s.tx.familyInvitation.deleteMany.mock.calls[0][0].where).toMatchObject({ invitedById: 'care', status: 'PENDING' });
    expect((s.audit.record.mock.calls as any[]).map((c) => c[0].action)).toEqual(['family.leave', 'family.caregiver_change']);
    const pushed = (s.notifications.notify.mock.calls as any[])[0][0];
    expect(pushed.map((n: any) => n.userId).sort()).toEqual(['early', 'late']);
    expect(pushed[0].data).toEqual({ kind: 'caregiver_changed' });
  });

  it('the last member leaves: the family is removed', async () => {
    const s = setup([{ id: 'm1', userId: 'care', role: 'CAREGIVER' }]);
    await s.family.leave('care');
    expect(s.tx.family.delete).toHaveBeenCalledWith({ where: { id: 'f1' } });
    expect(s.events).toEqual([]);
  });

  it('not in a family: 404', async () => {
    await expect(setup([]).family.leave('x')).rejects.toThrow(NotFoundException);
  });
});

describe('remove (caregiver only)', () => {
  it('REMOVED event with the caregiver as actor, and only the removed member gets a neutral push', async () => {
    const s = setup(FAMILY);
    await s.family.removeMember('care', 'late');
    expect(s.events).toEqual([{ familyId: 'f1', kind: 'REMOVED', subjectUserId: 'late', actorUserId: 'care' }]);
    expect((s.audit.record.mock.calls as any[])[0][0]).toMatchObject({ actorId: 'care', subjectUserId: 'late', action: 'family.remove' });
    const pushed = (s.notifications.notify.mock.calls as any[])[0][0];
    expect(pushed).toHaveLength(1);
    expect(pushed[0]).toMatchObject({ userId: 'late', type: 'SYSTEM', data: { kind: 'family_removed' } });
  });

  it('a member cannot remove; the caregiver cannot remove themself; someone outside the family is 404', async () => {
    const s = setup(FAMILY);
    await expect(s.family.removeMember('early', 'late')).rejects.toThrow(ForbiddenException);
    await expect(s.family.removeMember('care', 'care')).rejects.toThrow(BadRequestException);
    await expect(s.family.removeMember('care', 'stranger')).rejects.toThrow(NotFoundException);
    expect(s.events).toEqual([]);
  });
});

describe('activity feed', () => {
  it('own family only, 10 per page, deleted accounts shown as Deleted user, no phones', async () => {
    const s = setup(FAMILY);
    const at = new Date('2026-10-30T10:00:00Z');
    s.tx.familyEvent.findMany.mockResolvedValueOnce(
      Array.from({ length: 11 }, (_, i) => ({
        id: `e${i}`,
        kind: 'LEFT',
        createdAt: at,
        subject: { id: 'gone', name: 'Deleted user', accountStatus: i === 0 ? 'DELETED' : 'ACTIVE' },
        actor: null,
      })),
    );
    const page = await s.family.listEvents('early');
    expect(s.tx.familyEvent.findMany.mock.calls[0][0]).toMatchObject({ where: { familyId: 'f1' }, take: 11 });
    expect(page.items).toHaveLength(10);
    expect(page.nextCursor).toBeTruthy();
    expect(page.items[0].subject).toEqual({ id: 'gone', name: 'Deleted user', deleted: true });
    expect(JSON.stringify(page)).not.toMatch(/phone/);
  });
});
