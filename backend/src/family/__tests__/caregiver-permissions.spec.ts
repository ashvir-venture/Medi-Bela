import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { CaregiverAccessService } from '../caregiver-access.service';
import { CaregiverPermissionsService } from '../caregiver-permissions.service';

/** Two-member family: caregiver c1 and member m1 (Round 18 permissions). */
function setup(perm: { view: boolean; manage: boolean; at?: Date | null } = { view: false, manage: false }) {
  const member: any = {
    id: 'fm-m1',
    familyId: 'f1',
    userId: 'm1',
    role: 'MEMBER',
    caregiverCanView: perm.view,
    caregiverCanManage: perm.manage,
    caregiverPermissionAt: perm.at ?? null,
    user: { name: 'Abba', profileVisibleToFamily: true, role: 'USER', accountStatus: 'ACTIVE' },
  };
  const caregiver: any = { id: 'fm-c1', familyId: 'f1', userId: 'c1', role: 'CAREGIVER', user: { id: 'c1', name: 'Rafi', languagePreference: 'EN' } };
  const notify = jest.fn(async () => undefined);
  const audit = { record: jest.fn(async () => undefined) };
  const prisma: any = {
    familyMember: {
      findUnique: jest.fn(async ({ where }: any) => (where.userId === 'm1' ? member : where.userId === 'c1' ? caregiver : null)),
      findFirst: jest.fn(async ({ where }: any) => {
        if (where.userId === 'm1' && where.familyId === 'f1') return member;
        if (where.role === 'CAREGIVER') return caregiver;
        return null;
      }),
      update: jest.fn(async ({ data }: any) => Object.assign(member, data)),
    },
    $transaction: async (fn: any) => fn(prisma),
  };
  const access = new CaregiverAccessService(prisma, { notify } as any);
  const permissions = new CaregiverPermissionsService(prisma, { notify } as any, audit as any);
  return { access, permissions, member, notify, audit };
}

describe('caregiver permissions (Round 18)', () => {
  it('both off by default: the caregiver can neither see nor change anything', async () => {
    const s = setup();
    await expect(s.access.resolve('c1', 'm1', 'view')).rejects.toMatchObject({ errorCode: 'CAREGIVER_NO_PERMISSION' });
    await expect(s.access.resolve('c1', 'm1', 'manage')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(s.access.resolve('c1', 'm1')).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('someone who is not the caregiver still gets 404 (no probing)', async () => {
    const s = setup({ view: true, manage: true });
    await expect(s.access.resolve('m1', 'c1', 'view')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('View lets the caregiver read, not change', async () => {
    const s = setup({ view: true, manage: false });
    await expect(s.access.resolve('c1', 'm1', 'view')).resolves.toMatchObject({ subjectId: 'm1', byCaregiver: true });
    await expect(s.access.resolve('c1', 'm1', 'manage')).rejects.toMatchObject({ errorCode: 'CAREGIVER_NO_PERMISSION' });
  });

  it('Manage lets the caregiver read and change', async () => {
    const s = setup({ view: false, manage: true });
    await expect(s.access.resolve('c1', 'm1', 'view')).resolves.toMatchObject({ byCaregiver: true });
    await expect(s.access.resolve('c1', 'm1', 'manage')).resolves.toMatchObject({ byCaregiver: true });
  });

  it('acting for yourself never needs a permission', async () => {
    const s = setup();
    await expect(s.access.resolve('m1', undefined, 'manage')).resolves.toEqual({ actorId: 'm1', subjectId: 'm1', byCaregiver: false });
  });

  it('the member is asked until they answer; Manage turns View on', async () => {
    const s = setup();
    expect(await s.permissions.get('m1')).toMatchObject({ applies: true, view: false, manage: false, answered: false, caregiver: { id: 'c1' } });
    const after = await s.permissions.set('m1', { view: false, manage: true });
    expect(after).toMatchObject({ view: true, manage: true, answered: true });
    expect(s.member.caregiverCanView).toBe(true);
    expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'family.permission' }), expect.anything());
  });

  it('the caregiver is told when it changes (neutral text), not when it stays the same', async () => {
    const s = setup({ view: true, manage: false, at: new Date() });
    await s.permissions.set('m1', { view: true, manage: false });
    expect(s.notify).not.toHaveBeenCalled();
    await s.permissions.set('m1', { view: false, manage: false });
    expect(s.notify).toHaveBeenCalledTimes(1);
    const [[[n]]] = s.notify.mock.calls as any;
    expect(n.userId).toBe('c1');
    expect(n.data.kind).toBe('caregiver_permission');
    expect(n.body).toContain('notifications only');
  });

  it('the caregiver has no permission question of their own', async () => {
    const s = setup();
    expect(await s.permissions.get('c1')).toMatchObject({ applies: false });
    await expect(s.permissions.set('c1', { view: true, manage: true })).rejects.toBeInstanceOf(NotFoundException);
  });
});
