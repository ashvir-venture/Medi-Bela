import { NotFoundException } from '@nestjs/common';
import { AccountStatus, Role } from '@prisma/client';
import { CAREGIVER_CHANGE_ACTIONS, ChangeHistoryService } from '../change-history.service';

function setup(rows: unknown[] = []) {
  const findMany = jest.fn(async () => rows);
  const prisma = { auditLog: { findMany } };
  const caregivers = {
    resolve: jest.fn(async (actorId: string, memberId: string) => {
      if (actorId !== 'carer') throw new NotFoundException('Family member not found');
      return { actorId, subjectId: memberId, byCaregiver: true };
    }),
  };
  const service = new ChangeHistoryService(prisma as never, caregivers as never);
  return { service, findMany, caregivers };
}

describe('ChangeHistoryService', () => {
  it('lists only caregiver changes: someone else, a USER account, a caregiver action', async () => {
    const { service, findMany } = setup();
    await service.mine('mother');
    const where = (findMany.mock.calls[0] as any)[0].where;
    expect(where.subjectUserId).toBe('mother');
    expect(where.actorId).toEqual({ not: 'mother' });
    expect(where.actor).toEqual({ role: Role.USER });
    expect(where.action.in).toEqual([...CAREGIVER_CHANGE_ACTIONS]);
    // Pharmacist / admin work on the member's account is not a caregiver change.
    for (const staff of ['prescription.prepare', 'prescription.reject', 'user.ban', 'user.delete']) {
      expect(where.action.in).not.toContain(staff);
    }
  });

  it('shows a deleted caregiver as "Deleted user" and pages 10 at a time', async () => {
    const rows = Array.from({ length: 11 }, (_, i) => ({
      id: `a${i}`,
      action: 'dose.give',
      entityType: 'medicine_dose',
      createdAt: new Date(2026, 10, 12, 10, 60 - i),
      actor: { id: 'carer', name: 'Rafi', accountStatus: i === 0 ? AccountStatus.DELETED : AccountStatus.ACTIVE },
    }));
    const { service } = setup(rows);
    const page = await service.mine('mother');
    expect(page.items).toHaveLength(10);
    expect(page.nextCursor).not.toBeNull();
    expect(page.items[0].actor).toEqual({ id: 'carer', name: 'Deleted user', deleted: true });
    expect(page.items[1].actor).toEqual({ id: 'carer', name: 'Rafi', deleted: false });
  });

  it("the member's page goes through CaregiverAccessService (404 for anyone else)", async () => {
    const { service, caregivers, findMany } = setup();
    await service.forMember('carer', 'mother');
    expect(caregivers.resolve).toHaveBeenCalledWith('carer', 'mother');
    expect((findMany.mock.calls[0] as any)[0].where.subjectUserId).toBe('mother');
    await expect(service.forMember('sister', 'mother')).rejects.toBeInstanceOf(NotFoundException);
  });
});
