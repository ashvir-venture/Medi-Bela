import { BadRequestException, ConflictException } from '@nestjs/common';
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
        create: jest.fn(async ({ data }: any) => ({ id: 'med-new', genericId: null, generic: null, formId: null, categoryId: null, manufacturer: null, ...data })),
        update: jest.fn(async ({ data }: any) => ({ id: 'med-1', brandName: 'Napa', generic: null, ...data })),
        findUnique: jest.fn(),
      },
      medicineGeneric: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(async ({ data }: any) => ({ id: 7, ...data })),
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

  it('an edit makes the editing pharmacist the record\'s "Created by"', async () => {
    prisma.doctor.findUnique.mockResolvedValue({ id: 'doc-1', name: 'Dr. A', createdById: 'pharm-1' });
    prisma.doctor.update.mockImplementation(async ({ data }: any) => ({ id: 'doc-1', name: 'Dr. A', ...data }));
    await service.updateDoctor('pharm-2', 'doc-1', { phone: '01711000000' });
    expect(prisma.doctor.update.mock.calls[0][0].data.createdById).toBe('pharm-2');

    prisma.medicine.findUnique = jest.fn().mockResolvedValue({ id: 'med-1', brandName: 'Seclo', createdById: 'user-1' });
    prisma.medicine.update = jest.fn(async ({ data }: any) => ({ id: 'med-1', brandName: 'Seclo', ...data }));
    await service.updateMedicine('pharm-2', 'med-1', { manufacturer: 'Square Pharma' });
    expect(prisma.medicine.update.mock.calls[0][0].data.createdById).toBe('pharm-2');
  });

  it('shows "Created by" and the patient count to admins only', async () => {
    const row = {
      id: 'med-1',
      brandName: 'Seclo',
      genericId: null,
      generic: null,
      formId: 1,
      categoryId: 2,
      manufacturer: 'Square Pharma',
      createdBy: { id: 'user-1', name: 'A patient', role: 'USER' },
    };
    prisma.medicine.findUnique = jest.fn().mockResolvedValue(row);
    prisma.$queryRaw = jest.fn().mockResolvedValue([{ n: 4 }]);

    const forPharmacist = await service.getMedicine('med-1');
    expect(forPharmacist).not.toHaveProperty('createdBy');
    expect(forPharmacist).not.toHaveProperty('patients');
    expect(forPharmacist.incomplete).toBe(false);

    const forAdmin: any = await service.getMedicine('med-1', true);
    expect(forAdmin.createdBy).toEqual(row.createdBy);
    expect(forAdmin.patients).toBe(4);
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

  describe('generic names', () => {
    it('links a typed generic to the existing one, ignoring case', async () => {
      prisma.medicineGeneric.findFirst.mockResolvedValue({ id: 3, name: 'Paracetamol' });
      const medicine: any = await service.createMedicine('pharm-1', { brandName: 'Ace', genericName: ' paracetamol ' });
      expect(prisma.medicineGeneric.findFirst.mock.calls[0][0].where.name).toEqual({
        equals: 'paracetamol',
        mode: 'insensitive',
      });
      expect(prisma.medicineGeneric.create).not.toHaveBeenCalled();
      expect(prisma.medicine.create.mock.calls[0][0].data.genericId).toBe(3);
      expect(medicine).toHaveProperty('genericName');
    });

    it('creates a new generic when none matches', async () => {
      prisma.medicineGeneric.findFirst.mockResolvedValue(null);
      await service.createMedicine('pharm-1', { brandName: 'Napa', genericName: 'Paracetamol' });
      expect(prisma.medicineGeneric.create.mock.calls[0][0].data).toEqual({ name: 'Paracetamol' });
      expect(prisma.medicine.create.mock.calls[0][0].data.genericId).toBe(7);
    });

    it('returns the winner when two pharmacists add the same new generic at once', async () => {
      prisma.medicineGeneric.findFirst.mockResolvedValueOnce(null).mockResolvedValueOnce({ id: 9, name: 'Paracetamol' });
      prisma.medicineGeneric.create.mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('dup', { code: 'P2002', clientVersion: 'test' }),
      );
      const generic = await service.findOrCreateGeneric('PARACETAMOL');
      expect(generic.id).toBe(9);
    });

    it('a picked generic id must exist, and wins over a typed name', async () => {
      prisma.medicineGeneric.findUnique.mockResolvedValue(null);
      await expect(service.createMedicine('pharm-1', { brandName: 'Napa', genericId: 99 })).rejects.toThrow(
        BadRequestException,
      );
      expect(prisma.medicine.create).not.toHaveBeenCalled();

      prisma.medicineGeneric.findUnique.mockResolvedValue({ id: 4 });
      await service.createMedicine('pharm-1', { brandName: 'Napa', genericId: 4, genericName: 'Other' });
      expect(prisma.medicine.create.mock.calls[0][0].data.genericId).toBe(4);
      expect(prisma.medicineGeneric.findFirst).not.toHaveBeenCalled();
    });

    it('an empty name removes the generic; leaving both out keeps it', async () => {
      prisma.medicine.findUnique.mockResolvedValue({ id: 'med-1', brandName: 'Napa', genericId: 3 });
      await service.updateMedicine('pharm-1', 'med-1', { genericName: '' });
      expect(prisma.medicine.update.mock.calls[0][0].data.genericId).toBeNull();

      await service.updateMedicine('pharm-1', 'med-1', { manufacturer: 'Beximco' });
      expect(prisma.medicine.update.mock.calls[1][0].data.genericId).toBeUndefined();
    });

    it('responses carry the flat genericName from the linked generic', async () => {
      prisma.medicine.findUnique.mockResolvedValue({
        id: 'med-1',
        brandName: 'Napa',
        genericId: 3,
        generic: { id: 3, name: 'Paracetamol' },
        formId: 1,
        categoryId: 2,
        manufacturer: 'Beximco',
      });
      const medicine: any = await service.getMedicine('med-1');
      expect(medicine.genericName).toBe('Paracetamol');
      expect(medicine.generic).toEqual({ id: 3, name: 'Paracetamol' });
    });
  });
});
