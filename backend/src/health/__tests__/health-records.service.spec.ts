import { BadRequestException, NotFoundException } from '@nestjs/common';
import { HealthRecordType, RangeState, SugarContext } from '@prisma/client';
import { HealthRecordsService } from '../health-records.service';

function makeFakePrisma(limits: any = null) {
  const records = new Map<string, any>();
  return {
    _records: records,
    healthLimits: { findUnique: jest.fn(async () => limits) },
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
  let audit: any;
  let notifications: any;
  let caregivers: any;

  const build = (limits: any = null) => {
    prisma = makeFakePrisma(limits);
    audit = { record: jest.fn() };
    notifications = { notify: jest.fn() };
    caregivers = {
      notifyMember: jest.fn(),
      caregiverOf: jest.fn(async () => ({ id: 'carer-1', languagePreference: 'EN', memberName: 'Rahim' })),
    };
    service = new HealthRecordsService(prisma, audit, notifications, caregivers);
  };

  beforeEach(() => build());

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

  describe('Round 15: limits and the caregiver', () => {
    const doctor = { bpSystolicHigh: 140, bpDiastolicHigh: 90, bpSystolicLow: 90, lowSugar: 3.9, fastingLow: 4.4, fastingHigh: 7, afterFoodHigh: 10, notifyFamily: true };

    it('stores no range state and alerts nobody without saved limits', async () => {
      const r = await service.create('user-1', { type: HealthRecordType.BLOOD_PRESSURE, value: '190/125', systolic: 190, diastolic: 125 });
      expect(r.rangeState).toBeNull();
      expect(notifications.notify).not.toHaveBeenCalled();
    });

    it('alerts the caregiver once, without values, when out of range', async () => {
      build(doctor);
      const r = await service.create('user-1', { type: HealthRecordType.BLOOD_SUGAR, value: '8.2', numericValue: 8.2, sugarContext: SugarContext.FASTING });
      expect(r.rangeState).toBe(RangeState.ABOVE);
      expect(notifications.notify).toHaveBeenCalledTimes(1);
      const [n] = notifications.notify.mock.calls[0][0];
      expect(n.userId).toBe('carer-1');
      expect(n.relatedEntityId).toBe(`reading:${r.id}`);
      expect(n.body).not.toContain('8.2');
      expect(n.data).toEqual({ kind: 'reading_alert', memberUserId: 'user-1' });
    });

    it('does not alert when "Tell my family" is off or the reading is in range', async () => {
      build({ ...doctor, notifyFamily: false });
      await service.create('user-1', { type: HealthRecordType.BLOOD_PRESSURE, value: '150/95', systolic: 150, diastolic: 95 });
      build(doctor);
      const r = await service.create('user-1', { type: HealthRecordType.BLOOD_PRESSURE, value: '120/80', systolic: 120, diastolic: 80 });
      expect(r.rangeState).toBe(RangeState.IN_RANGE);
      expect(notifications.notify).not.toHaveBeenCalled();
    });

    it('a caregiver entry is tagged, audited and told to the member, and the caregiver is not alerted about it', async () => {
      build(doctor);
      const r = await service.create(
        { actorId: 'carer-1', subjectId: 'user-1', byCaregiver: true },
        { type: HealthRecordType.BLOOD_PRESSURE, value: '160/100', systolic: 160, diastolic: 100 },
      );
      expect(r.byCaregiver).toBe(true);
      expect((r as any).enteredById).toBeUndefined();
      expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'health_record.create' }));
      expect(caregivers.notifyMember).toHaveBeenCalledWith(expect.anything(), 'health_updated', `record:${r.id}`);
      expect(notifications.notify).not.toHaveBeenCalled();
    });

    it('rejects structured fields that do not fit the type', async () => {
      await expect(service.create('user-1', { type: HealthRecordType.WEIGHT, value: '70', systolic: 120 })).rejects.toThrow(BadRequestException);
      await expect(service.create('user-1', { type: HealthRecordType.BLOOD_PRESSURE, value: '120', systolic: 120 })).rejects.toThrow(BadRequestException);
      await expect(service.create('user-1', { type: HealthRecordType.WEIGHT, value: '900', numericValue: 900 })).rejects.toThrow(BadRequestException);
    });
  });
});
