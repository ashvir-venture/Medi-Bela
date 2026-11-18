import { BadRequestException } from '@nestjs/common';
import { RoutineManagementService } from '../routine-management.service';
import { OTHER_CONDITION_CODE } from '../lib/other-condition';

/** "Other" in "For which condition" (owner 2026-11-18). */
function setup(rows: string[] = ['diabetes']) {
  const prisma: any = {
    condition: { findUnique: jest.fn(async ({ where }: any) => (rows.includes(where.code) ? { code: where.code } : null)) },
  };
  const service = new RoutineManagementService(prisma, { record: jest.fn() } as any, {} as any, {} as any, {} as any);
  return { service, prisma };
}

describe('medicine condition tag', () => {
  it('accepts "other" without a conditions row', async () => {
    const s = setup();
    await expect((s.service as any).checkCondition(OTHER_CONDITION_CODE)).resolves.toBe('other');
    expect(s.prisma.condition.findUnique).not.toHaveBeenCalled();
  });

  it('still checks every other code against the conditions table', async () => {
    const s = setup();
    await expect((s.service as any).checkCondition('diabetes')).resolves.toBe('diabetes');
    await expect((s.service as any).checkCondition('made_up')).rejects.toBeInstanceOf(BadRequestException);
  });
});
