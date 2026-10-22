import { NotFoundException } from '@nestjs/common';
import { HealthRecordType } from '@prisma/client';
import { HealthRecordsService } from '../health-records.service';

function makeFakePrisma() {
  const records = new Map<string, any>();
  return {
    _records: records,
    healthRecord: {
      create: jest.fn(async ({ data }: any) => {
        const record = { id: `record-${records.size + 1}`, ...data };
        records.set(record.id, record);
        return record;
      }),
      findMany: jest.fn(async ({ where }: any) =>
        [...records.values()].filter((r) => r.userId === where.userId),
      ),
      findUnique: jest.fn(async ({ where }: any) => records.get(where.id) ?? null),
      update: jest.fn(async ({ where, data }: any) => {
        const r = records.get(where.id);
        Object.assign(r, data);
        return r;
      }),
    },
  } as any;
}

describe('HealthRecordsService', () => {
  let prisma: any;
  let service: HealthRecordsService;

  beforeEach(() => {
    prisma = makeFakePrisma();
    service = new HealthRecordsService(prisma);
  });

  it('creates a record defaulting recordedAt to now when omitted', async () => {
    const before = Date.now();
    const record = await service.create('user-1', {
      type: HealthRecordType.BLOOD_SUGAR,
      value: '110',
      unit: 'mg/dL',
    });
    expect(record.recordedAt.getTime()).toBeGreaterThanOrEqual(before);
  });

  it("throws NotFoundException for another user's record", async () => {
    await service.create('user-1', { type: HealthRecordType.WEIGHT, value: '70' });
    const otherUsersRecord = [...prisma._records.values()][0];
    await expect(service.getDetail('user-2', otherUsersRecord.id)).rejects.toThrow(
      NotFoundException,
    );
  });

  it('update only touches value/unit/notes, never type or recordedAt', async () => {
    const record = await service.create('user-1', {
      type: HealthRecordType.BLOOD_PRESSURE,
      value: '120/80',
      recordedAt: '2026-01-01T00:00:00.000Z',
    });
    const updated = await service.update('user-1', record.id, { value: '118/78' });
    expect(updated.value).toBe('118/78');
    expect(updated.type).toBe(HealthRecordType.BLOOD_PRESSURE);
    expect(updated.recordedAt).toEqual(new Date('2026-01-01T00:00:00.000Z'));
  });
});
