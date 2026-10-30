import { NotFoundException } from '@nestjs/common';
import { AuditLogService } from '../audit-log.service';

function setup(rows: any[] = []) {
  const prisma: any = {
    auditLog: {
      findMany: jest.fn(async () => rows),
      findUnique: jest.fn(async () => null),
      groupBy: jest.fn(async () => [{ action: 'doctor.create' }, { action: 'prescription.reject' }]),
    },
    user: { findMany: jest.fn(async () => [{ id: 'p1', name: 'Pharm', role: 'PHARMACIST' }]) },
  };
  return { service: new AuditLogService(prisma), prisma };
}

describe('AuditLogService', () => {
  const offset = process.env.APP_UTC_OFFSET_MINUTES;
  afterEach(() => {
    if (offset === undefined) delete process.env.APP_UTC_OFFSET_MINUTES;
    else process.env.APP_UTC_OFFSET_MINUTES = offset;
  });

  it('pages 20 at a time, newest first, without phone numbers', async () => {
    const { service, prisma } = setup();
    await service.list({});
    const arg = prisma.auditLog.findMany.mock.calls[0][0];
    expect(arg.take).toBe(21);
    expect(arg.orderBy).toEqual([{ createdAt: 'desc' }, { id: 'desc' }]);
    expect(JSON.stringify(arg.select)).not.toContain('phone');
    expect(arg.select.before).toBeUndefined();
  });

  it('applies action, actor and role filters', async () => {
    const { service, prisma } = setup();
    await service.list({ action: 'prescription.reject', actorId: 'a1', actorRole: 'PHARMACIST' as any });
    expect(prisma.auditLog.findMany.mock.calls[0][0].where.AND[0]).toEqual({
      action: 'prescription.reject',
      actorId: 'a1',
      actor: { role: 'PHARMACIST' },
    });
  });

  it('reads from/to as whole days in the app timezone (Dhaka, UTC+6), "to" inclusive', async () => {
    delete process.env.APP_UTC_OFFSET_MINUTES;
    const { service, prisma } = setup();
    await service.list({ from: '2026-10-01', to: '2026-10-02' });
    const { createdAt } = prisma.auditLog.findMany.mock.calls[0][0].where.AND[0];
    expect(createdAt.gte.toISOString()).toBe('2026-09-30T18:00:00.000Z');
    expect(createdAt.lt.toISOString()).toBe('2026-10-02T18:00:00.000Z');
  });

  it('filters list the actions seen and the staff accounts', async () => {
    const { service } = setup();
    expect(await service.filters()).toEqual({
      actions: ['doctor.create', 'prescription.reject'],
      actors: [{ id: 'p1', name: 'Pharm', role: 'PHARMACIST' }],
    });
  });

  it('detail includes before/after; unknown id is 404', async () => {
    const { service, prisma } = setup();
    await expect(service.detail('x')).rejects.toThrow(NotFoundException);
    expect(prisma.auditLog.findUnique.mock.calls[0][0].select).toMatchObject({ before: true, after: true });
  });
});
