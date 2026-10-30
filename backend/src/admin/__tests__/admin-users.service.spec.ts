import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { AdminUsersService } from '../admin-users.service';

function setup(target: any) {
  const tx: any = {
    user: { update: jest.fn(async () => ({})) },
    medicineDose: { deleteMany: jest.fn(async () => ({ count: 0 })) },
    medicineRoutine: { updateMany: jest.fn(async () => ({ count: 0 })) },
  };
  const prisma: any = {
    user: { findUnique: jest.fn(async () => target), findMany: jest.fn(async () => []) },
    medicineRoutine: { findMany: jest.fn(async () => []) },
    $transaction: async (fn: any) => fn(tx),
  };
  const audit = { record: jest.fn(async (..._args: any[]) => undefined) };
  const notifications = { endSessions: jest.fn(async () => undefined) };
  const service = new AdminUsersService(prisma, audit as any, notifications as any);
  return { service, prisma, tx, audit, notifications };
}

describe('AdminUsersService ban / unban', () => {
  it('ban: SUSPENDED, signed out everywhere, reminders paused, audited with the admin as actor', async () => {
    const s = setup({ id: 'u1', role: 'USER', accountStatus: 'ACTIVE' });
    await s.service.ban('admin1', 'u1');
    const data = s.tx.user.update.mock.calls[0][0].data;
    expect(data.accountStatus).toBe('SUSPENDED');
    expect(data.suspendedAt).toBeInstanceOf(Date);
    expect(data.passwordChangedAt).toBeInstanceOf(Date);
    expect(s.tx.medicineDose.deleteMany).toHaveBeenCalled();
    expect(s.notifications.endSessions).toHaveBeenCalledWith('u1');
    expect((s.audit.record.mock.calls as any[])[0][0]).toMatchObject({ actorId: 'admin1', subjectUserId: 'u1', action: 'user.ban' });
  });

  it('pharmacists can be banned; admins never (including oneself)', async () => {
    await expect(setup({ id: 'p1', role: 'PHARMACIST', accountStatus: 'ACTIVE' }).service.ban('a', 'p1')).resolves.toBeTruthy();
    const s = setup({ id: 'admin1', role: 'ADMIN', accountStatus: 'ACTIVE' });
    await expect(s.service.ban('admin1', 'admin1')).rejects.toThrow(ForbiddenException);
    expect(s.tx.user.update).not.toHaveBeenCalled();
  });

  it('a deactivated user can be banned, and unban returns ACTIVE and resumes routines', async () => {
    await expect(setup({ id: 'u1', role: 'USER', accountStatus: 'DEACTIVATED' }).service.ban('a', 'u1')).resolves.toBeTruthy();
    const s = setup({ id: 'u1', role: 'USER', accountStatus: 'SUSPENDED' });
    await s.service.unban('a', 'u1');
    expect(s.tx.user.update.mock.calls[0][0].data).toEqual({ accountStatus: 'ACTIVE', suspendedAt: null, deactivatedAt: null });
    expect(s.prisma.medicineRoutine.findMany).toHaveBeenCalled();
    expect((s.audit.record.mock.calls as any[])[0][0].action).toBe('user.unban');
  });

  it('unban of an account that is not suspended, ban twice, or a deleted / unknown account are refused', async () => {
    await expect(setup({ id: 'u1', role: 'USER', accountStatus: 'ACTIVE' }).service.unban('a', 'u1')).rejects.toThrow(ConflictException);
    await expect(setup({ id: 'u1', role: 'USER', accountStatus: 'SUSPENDED' }).service.ban('a', 'u1')).rejects.toThrow(ConflictException);
    await expect(setup({ id: 'u1', role: 'USER', accountStatus: 'DELETED' }).service.ban('a', 'u1')).rejects.toThrow(NotFoundException);
    await expect(setup(null).service.ban('a', 'u1')).rejects.toThrow(NotFoundException);
  });
});

describe('AdminUsersService list filters', () => {
  const whereOf = async (query: any) => {
    const s = setup(null);
    await s.service.list(query);
    return s.prisma.user.findMany.mock.calls[0][0].where;
  };

  it('hides deleted accounts unless that status is chosen', async () => {
    expect((await whereOf({})).accountStatus).toEqual({ not: 'DELETED' });
    expect((await whereOf({ status: 'DELETED' })).accountStatus).toBe('DELETED');
  });

  it('a complete number matches any stored spelling; a part matches anywhere', async () => {
    for (const typed of ['01712345678', '+8801712345678', '8801712345678']) {
      const w = await whereOf({ phone: typed });
      expect(w.AND[0].phone.in).toEqual(expect.arrayContaining(['+8801712345678', '01712345678']));
    }
    expect((await whereOf({ phone: '345 67' })).AND[0]).toEqual({ phone: { contains: '34567' } });
  });

  it('age band: from date of birth, or birth year when the date was erased', async () => {
    const w = await whereOf({ ageBand: '60+' });
    const [byDate, byYear] = w.AND[0].OR;
    expect(byDate.dateOfBirth.lte).toBeInstanceOf(Date);
    expect(byYear.dateOfBirth).toBeNull();
    const year = new Date().getUTCFullYear();
    expect(byYear.birthYear.lte).toBeGreaterThanOrEqual(year - 61);
    expect(byYear.birthYear.lte).toBeLessThanOrEqual(year - 59);
  });

  it('role and division filters pass through; admins are listed but cannot be banned', async () => {
    const s = setup(null);
    s.prisma.user.findMany.mockResolvedValueOnce([
      { id: 'a', role: 'ADMIN', accountStatus: 'ACTIVE', createdAt: new Date() },
      { id: 'u', role: 'USER', accountStatus: 'ACTIVE', createdAt: new Date() },
    ]);
    const page = await s.service.list({ role: 'USER', divisionId: 3 } as any);
    expect(s.prisma.user.findMany.mock.calls[0][0].where).toMatchObject({ role: 'USER', divisionId: 3 });
    expect(page.items.map((i: any) => i.canBan)).toEqual([false, true]);
  });
});
