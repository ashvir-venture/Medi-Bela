import { BadRequestException, NotFoundException } from '@nestjs/common';
import { OwnTestStatus } from '@prisma/client';
import { MAX_PHOTOS, RecordsService } from '../records.service';

const self = { actorId: 'u1', subjectId: 'u1', byCaregiver: false };
const carer = { actorId: 'c1', subjectId: 'u1', byCaregiver: true };

const HBA1C = { id: 1, code: 'hba1c', fields: [{ id: 11, code: 'hba1c', nameEn: 'HbA1c', unit: '%' }] };

function build() {
  const prisma: any = {
    condition: { findUnique: jest.fn(async ({ where }: any) => (where.code === 'diabetes' ? { id: 1 } : null)) },
    doctor: { findUnique: jest.fn(async ({ where }: any) => (where.id === '00000000-0000-0000-0000-00000000000d' ? { id: where.id } : null)) },
    myDoctor: {
      findUnique: jest.fn(async ({ where }: any) => (where.id === 'mine-1' ? { userId: 'u1' } : { userId: 'other' })),
      findFirst: jest.fn(async () => null),
      create: jest.fn(async ({ data }: any) => ({ id: 'mine-new', ...data })),
    },
    testKind: { findUnique: jest.fn(async ({ where }: any) => (where.code === 'hba1c' ? HBA1C : null)) },
    healthReminder: { findUnique: jest.fn(async () => ({ userId: 'u1' })) },
    ownTest: {
      create: jest.fn(async ({ data }: any) => ({
        id: 't1',
        userId: data.userId,
        createdById: data.createdById,
        testKind: data.testKindId ? { code: 'hba1c' } : null,
        otherName: data.otherName,
        status: data.status,
        date: data.date,
        remind: data.remind,
        fasting: data.fasting,
        findings: data.findings,
        lab: data.lab,
        conditionCode: data.conditionCode,
        healthReminderId: data.healthReminderId,
        values: data.values.create.map((v: any, i: number) => ({ id: `v${i}`, ...v })),
        photos: [],
        createdAt: new Date(),
      })),
      findUnique: jest.fn(async () => ({ userId: 'u1' })),
    },
    appointment: {
      create: jest.fn(async ({ data }: any) => ({ id: 'a1', ...data, doctor: null, myDoctor: data.myDoctorId ? { id: data.myDoctorId, name: 'Dr Karim', chamber: null, area: null } : null, doneAt: null, createdAt: new Date() })),
    },
    recordPhoto: {
      count: jest.fn(async () => 0),
      create: jest.fn(async ({ data }: any) => ({ id: 'p1', ...data })),
    },
  };
  prisma.$transaction = async (fn: any) => fn(prisma);
  const audit = { record: jest.fn() };
  const caregivers = { notifyMember: jest.fn() };
  const cloudinary = {
    uploadPrivateImage: jest.fn(async () => 'https://res.cloudinary.com/x/image/authenticated/v1/records/p.jpg'),
    signedImageUrl: jest.fn((url: string) => `${url}?signed`),
    deleteImageByUrl: jest.fn(),
  };
  const service = new RecordsService(prisma, audit as any, caregivers as any, cloudinary as any);
  return { service, prisma, audit, caregivers, cloudinary };
}

describe('RecordsService (Round 16)', () => {
  it('a typed doctor becomes one of mine, never a catalog row', async () => {
    const s = build();
    const a = await s.service.createAppointment(self, { date: '2026-11-20', newDoctor: { name: 'Dr Karim' } } as any);
    expect(s.prisma.myDoctor.create).toHaveBeenCalledWith({ data: { userId: 'u1', name: 'Dr Karim', chamber: null, area: null } });
    expect(a.doctor).toEqual(expect.objectContaining({ source: 'MINE', name: 'Dr Karim' }));
    expect(a.remind).toBe(true);
    expect(a.kind).toBe('VISIT');
  });

  it('refuses two doctors at once, a stranger’s private doctor and an unknown condition', async () => {
    const s = build();
    await expect(s.service.createAppointment(self, { date: '2026-11-20', myDoctorId: 'mine-1', newDoctor: { name: 'X' } } as any)).rejects.toThrow(BadRequestException);
    await expect(s.service.createAppointment(self, { date: '2026-11-20', myDoctorId: 'mine-2' } as any)).rejects.toThrow(BadRequestException);
    await expect(s.service.createAppointment(self, { date: '2026-11-20', conditionCode: 'nope' } as any)).rejects.toThrow(BadRequestException);
  });

  it('a result keeps values by the test kind’s fields and named extras', async () => {
    const s = build();
    const t = await s.service.createTest(self, {
      testKindCode: 'hba1c',
      status: OwnTestStatus.DONE,
      date: '2026-11-06',
      values: [{ fieldCode: 'hba1c', value: 7.4 }, { name: 'Glucose', value: 9.1, unit: 'mmol/L' }, { fieldCode: 'hba1c', value: null }],
    } as any);
    expect(t.values.map((v: any) => [v.name, v.value, v.unit, v.fieldId])).toEqual([
      ['HbA1c', 7.4, '%', 11],
      ['Glucose', 9.1, 'mmol/L', null],
    ]);
    await expect(
      s.service.createTest(self, { testKindCode: 'hba1c', status: OwnTestStatus.DONE, date: '2026-11-06', values: [{ fieldCode: 'tsh', value: 2 }] } as any),
    ).rejects.toThrow(BadRequestException);
  });

  it('an upcoming test stores no values; "Other" needs a name', async () => {
    const s = build();
    const t = await s.service.createTest(self, { otherName: 'Vitamin D', date: '2026-11-20', fasting: true, values: [{ name: 'x', value: 1 }] } as any);
    expect(t.values).toEqual([]);
    expect(t.status).toBe('UPCOMING');
    expect(t.fasting).toBe(true);
    await expect(s.service.createTest(self, { date: '2026-11-20' } as any)).rejects.toThrow(BadRequestException);
  });

  it('photos are private uploads sent back as signed links, up to the limit', async () => {
    const s = build();
    const p = await s.service.addPhoto(carer, { ownTestId: 't1' }, Buffer.from('x'), 'a.jpg');
    expect(s.cloudinary.uploadPrivateImage).toHaveBeenCalledWith(expect.any(Buffer), 'a.jpg', 'records');
    expect(p.imageUrl).toMatch(/\?signed$/);
    expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'record.photo_add' }));
    s.prisma.recordPhoto.count.mockResolvedValueOnce(MAX_PHOTOS);
    await expect(s.service.addPhoto(self, { ownTestId: 't1' }, Buffer.from('x'), 'b.jpg')).rejects.toThrow(BadRequestException);
    s.prisma.ownTest.findUnique.mockResolvedValueOnce({ userId: 'someone-else' });
    await expect(s.service.addPhoto(self, { ownTestId: 't1' }, Buffer.from('x'), 'c.jpg')).rejects.toThrow(NotFoundException);
  });

  it('a caregiver entry is tagged, audited and told to the member', async () => {
    const s = build();
    const t = await s.service.createTest(carer, { testKindCode: 'hba1c', date: '2026-11-20' } as any);
    expect(t.byCaregiver).toBe(true);
    expect(s.audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'record.test_create' }), expect.anything());
    expect(s.caregivers.notifyMember).toHaveBeenCalledWith(carer, 'health_updated', 'test:t1');
  });
});
