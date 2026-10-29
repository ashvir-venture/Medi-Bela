import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { CatalogService, prefixPattern } from '../catalog.service';

describe('prefixPattern', () => {
  it('lower-cases, trims and appends %', () => {
    expect(prefixPattern('  NAPA ')).toBe('napa%');
  });

  it('escapes LIKE wildcards typed by the user', () => {
    expect(prefixPattern('50%_x\\')).toBe('50\\%\\_x\\\\%');
  });
});

describe('CatalogService', () => {
  let prisma: any;
  let audit: { record: jest.Mock };
  let service: CatalogService;

  beforeEach(() => {
    prisma = {
      doctor: {
        findUnique: jest.fn(),
        create: jest.fn(async ({ data }: any) => ({ id: 'doc-new', ...data })),
        update: jest.fn(),
      },
      medicine: {
        findFirst: jest.fn(),
        create: jest.fn(async ({ data }: any) => ({ id: 'med-new', genericName: null, formId: null, categoryId: null, manufacturer: null, ...data })),
      },
    };
    audit = { record: jest.fn().mockResolvedValue(undefined) };
    service = new CatalogService(prisma, audit as any);
  });

  it('reuses the doctor with the same BMDC number instead of creating a duplicate', async () => {
    prisma.doctor.findUnique.mockResolvedValue({ id: 'doc-1', name: 'Dr. A', bmdcNumber: 'A-1' });
    const doctor = await service.createDoctor('pharm-1', { name: 'Dr. A.', bmdcNumber: 'A-1' });
    expect(doctor.id).toBe('doc-1');
    expect(prisma.doctor.create).not.toHaveBeenCalled();
  });

  it('creates a doctor and audits it without the phone number', async () => {
    prisma.doctor.findUnique.mockResolvedValue(null);
    await service.createDoctor('pharm-1', { name: 'Dr. B', phone: '01711000000' });
    expect(prisma.doctor.create).toHaveBeenCalled();
    const [[entry]] = audit.record.mock.calls;
    expect(entry).toMatchObject({ action: 'doctor.create', actorId: 'pharm-1' });
    expect(JSON.stringify(entry)).not.toContain('01711000000');
  });

  it('maps a duplicate BMDC number on update to 409', async () => {
    prisma.doctor.findUnique.mockResolvedValue({ id: 'doc-1', name: 'Dr. A' });
    prisma.doctor.update.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('dup', { code: 'P2002', clientVersion: 'test' }),
    );
    await expect(service.updateDoctor('pharm-1', 'doc-1', { bmdcNumber: 'A-2' })).rejects.toThrow(
      ConflictException,
    );
  });

  it('links a typed medicine to an existing one by brand name, ignoring case', async () => {
    prisma.medicine.findFirst.mockResolvedValue({ id: 'med-1' });
    const id = await service.findOrCreateMedicineStub('pharm-1', ' napa ', prisma);
    expect(id).toBe('med-1');
    expect(prisma.medicine.findFirst.mock.calls[0][0].where.brandName).toEqual({
      equals: 'napa',
      mode: 'insensitive',
    });
    expect(prisma.medicine.create).not.toHaveBeenCalled();
  });

  it('creates a stub for a new medicine for a pharmacist to complete later', async () => {
    prisma.medicine.findFirst.mockResolvedValue(null);
    const id = await service.findOrCreateMedicineStub('pharm-1', 'Newmed', prisma);
    expect(id).toBe('med-new');
    expect(prisma.medicine.create.mock.calls[0][0].data).toEqual({ brandName: 'Newmed', createdById: 'pharm-1' });
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'medicine.create' }), prisma);
  });
});
