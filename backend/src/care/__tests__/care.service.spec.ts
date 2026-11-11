import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CareLogKind } from '@prisma/client';
import { appDate, CareService, checkLogData } from '../care.service';

const self = { actorId: 'u1', subjectId: 'u1', byCaregiver: false };
const carer = { actorId: 'c1', subjectId: 'u1', byCaregiver: true };

function build() {
  const settings = new Map<string, any>();
  const prisma: any = {
    condition: {
      findUnique: jest.fn(async ({ where }: any) => (['diabetes', 'pregnancy', 'cancer', 'asthma'].includes(where.code) ? { id: 1, code: where.code } : null)),
      findMany: jest.fn(async ({ where }: any) => where.code.in.filter((c: string) => c !== 'nope').map((code: string, i: number) => ({ id: i + 1, code }))),
    },
    careSetting: {
      findUnique: jest.fn(async ({ where }: any) => settings.get(where.userId_conditionCode.conditionCode) ?? null),
      upsert: jest.fn(async ({ create, update }: any) => {
        settings.set(create.conditionCode, { data: update.data });
      }),
    },
    healthLimits: {
      findUnique: jest.fn(async () => ({ userId: 'u1', fastingLow: 4.4, fastingHigh: 7, tshLow: null, tshHigh: null })),
      upsert: jest.fn(async ({ update }: any) => ({ userId: 'u1', updatedById: update.updatedById, ...update })),
    },
    dayTick: { upsert: jest.fn(), deleteMany: jest.fn() },
    careLog: {
      findUnique: jest.fn(async () => null),
      create: jest.fn(async ({ data }: any) => ({ id: 'l1', createdAt: new Date(), ...data })),
    },
    userCondition: { deleteMany: jest.fn(), createMany: jest.fn() },
    user: { update: jest.fn() },
  };
  prisma.$transaction = async (fn: any) => fn(prisma);
  const audit = { record: jest.fn() };
  const notifications = { notify: jest.fn() };
  const caregivers = {
    notifyMember: jest.fn(),
    caregiverOf: jest.fn(async () => ({ id: 'c1', languagePreference: 'BN', memberName: 'Abba' })),
  };
  const service = new CareService(prisma, audit as any, notifications as any, caregivers as any);
  return { service, prisma, audit, notifications, caregivers, settings };
}

describe('CareService (Round 15)', () => {
  it('appDate uses the app time zone', () => {
    expect(appDate(new Date('2026-11-10T19:30:00Z'), 360)).toBe('2026-11-11');
    expect(appDate(new Date('2026-11-10T17:30:00Z'), 360)).toBe('2026-11-10');
  });

  describe('settings', () => {
    it('accepts the care plan and the condition fields, merges, and null clears', async () => {
      const s = build();
      await s.service.updateSetting(self, 'pregnancy', { dueDate: '2027-03-01', habits: ['ifa'] } as any);
      const r = await s.service.updateSetting(self, 'pregnancy', { dueDate: null, startWeightKg: 55 } as any);
      expect(r.data).toEqual({ habits: ['ifa'], startWeightKg: 55 });
    });

    it("rejects another condition's field and unknown conditions", async () => {
      const s = build();
      await expect(s.service.updateSetting(self, 'diabetes', { dueDate: '2027-03-01' } as any)).rejects.toThrow(BadRequestException);
      await expect(s.service.updateSetting(self, 'nope', {} as any)).rejects.toThrow(NotFoundException);
    });

    it('checks custom habits, test frequencies and chemo cycles', async () => {
      const s = build();
      await expect(s.service.updateSetting(self, 'diabetes', { customHabits: { bad: 'x' } } as any)).rejects.toThrow(BadRequestException);
      await expect(s.service.updateSetting(self, 'diabetes', { testEveryMonths: { hba1c: 2 } } as any)).rejects.toThrow(BadRequestException);
      await expect(s.service.updateSetting(self, 'cancer', { chemoTotal: 4, chemoDone: 5 } as any)).rejects.toThrow(BadRequestException);
      const ok = await s.service.updateSetting(self, 'diabetes', { customHabits: { u_abc1: 'Drink tea without sugar' }, testEveryMonths: { hba1c: 3 } } as any);
      expect(ok.data.testEveryMonths).toEqual({ hba1c: 3 });
    });

    it('a caregiver change is audited and told to the member', async () => {
      const s = build();
      await s.service.updateSetting(carer, 'asthma', { triggers: ['dust'] } as any);
      expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'care.settings', actorId: 'c1', subjectUserId: 'u1' }), expect.anything());
      expect(s.caregivers.notifyMember).toHaveBeenCalledWith(carer, 'health_updated', expect.stringContaining('settings:asthma'));
    });
  });

  describe('limits', () => {
    it('refuses a lowest above the highest, including the saved value', async () => {
      const s = build();
      await expect(s.service.updateLimits(self, { fastingLow: 8 })).rejects.toThrow(BadRequestException);
      await expect(s.service.updateLimits(self, { tshLow: 4, tshHigh: 0.4 })).rejects.toThrow(BadRequestException);
      const saved = await s.service.updateLimits(carer, { fastingHigh: 7.5 });
      expect(saved.byCaregiver).toBe(true);
      expect((saved as any).updatedById).toBeUndefined();
    });

    it('audits which numbers changed, never their values', async () => {
      const s = build();
      await s.service.updateLimits(carer, { bpSystolicHigh: 135 });
      const entry = s.audit.record.mock.calls[0][0];
      expect(entry.after).toEqual({ fields: ['bpSystolicHigh'], byCaregiver: true });
    });
  });

  describe('ticks', () => {
    it('only the last 7 days, never the future', async () => {
      const s = build();
      const now = new Date('2026-11-11T06:00:00Z');
      await expect(s.service.setTick(self, { key: 'habit:walk', day: '2026-11-12', done: true }, now)).rejects.toThrow(BadRequestException);
      await expect(s.service.setTick(self, { key: 'habit:walk', day: '2026-11-04', done: true }, now)).rejects.toThrow(BadRequestException);
      await s.service.setTick(self, { key: 'habit:walk', day: '2026-11-05', done: true }, now);
      await s.service.setTick(self, { key: 'habit:walk', day: '2026-11-11', done: false }, now);
      expect(s.prisma.dayTick.upsert).toHaveBeenCalledTimes(1);
      expect(s.prisma.dayTick.deleteMany).toHaveBeenCalledTimes(1);
    });
  });

  describe('care logs', () => {
    it('keeps only each kind’s own fields', () => {
      expect(checkLogData({ kind: CareLogKind.KICKS, data: { count: 10, minutes: 25, extra: 1 } } as any)).toEqual({ count: 10, minutes: 25 });
      expect(checkLogData({ kind: CareLogKind.RELIEVER, data: {} } as any)).toEqual({ puffs: 1 });
      expect(checkLogData({ kind: CareLogKind.SYMPTOMS, conditionCode: 'bp', data: { symptoms: ['chest'] } } as any)).toEqual({ symptoms: ['chest'], fine: false });
      expect(checkLogData({ kind: CareLogKind.SYMPTOMS, conditionCode: 'bp', data: { symptoms: ['x'], fine: true } } as any)).toEqual({ symptoms: [], fine: true });
      expect(() => checkLogData({ kind: CareLogKind.SYMPTOMS, data: { symptoms: ['chest'] } } as any)).toThrow(BadRequestException);
      expect(() => checkLogData({ kind: CareLogKind.SYMPTOMS, conditionCode: 'bp', data: { symptoms: [] } } as any)).toThrow(BadRequestException);
      expect(() => checkLogData({ kind: CareLogKind.KICKS, data: { count: -1, minutes: 5 } } as any)).toThrow(BadRequestException);
      expect(() => checkLogData({ kind: CareLogKind.TD_DOSE, data: { date: 'soon' } } as any)).toThrow(BadRequestException);
    });

    it('a caregiver entry is tagged without exposing who', async () => {
      const s = build();
      const log = await s.service.createLog(carer, { kind: CareLogKind.RELIEVER, data: { puffs: 2 } } as any);
      expect(log.byCaregiver).toBe(true);
      expect((log as any).enteredById).toBeUndefined();
      expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'care.log' }));
    });
  });

  describe('Alert family', () => {
    it('one neutral push to the caregiver per minute', async () => {
      const s = build();
      const now = new Date('2026-11-11T06:00:30Z');
      expect(await s.service.alertFamily('u1', now)).toEqual({ notified: true });
      const [n] = s.notifications.notify.mock.calls[0][0];
      expect(n.userId).toBe('c1');
      expect(n.relatedEntityId).toBe(`help:u1:${Math.floor(now.getTime() / 60000)}`);
      expect(n.data).toEqual({ kind: 'help_alert', memberUserId: 'u1' });
    });

    it('nobody to tell: no push', async () => {
      const s = build();
      s.caregivers.caregiverOf.mockResolvedValueOnce(null as any);
      expect(await s.service.alertFamily('u1')).toEqual({ notified: false });
      expect(s.notifications.notify).not.toHaveBeenCalled();
    });
  });

  it('unknown condition codes are refused', async () => {
    const s = build();
    await expect(s.service.setConditions(self, { codes: ['diabetes', 'nope'] })).rejects.toThrow(BadRequestException);
  });
});
