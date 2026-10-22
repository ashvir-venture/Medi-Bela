import { ConflictException, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { HealthSuggestionsService } from '../health-suggestions.service';

const ROUTINE = { id: 'r1', userId: 'u1', medicineName: 'Metformin', dosage: '500mg' };
const GENERATED = { en: [{ category: 'Test', text: 'Ask about HbA1c.' }], bn: [{ category: 'পরীক্ষা', text: 'HbA1c' }] };

function setup(opts: { generated?: any; configured?: boolean; routine?: any; draft?: any } = {}) {
  const create = jest.fn(async ({ data }: any) => ({ id: 'new', ...data }));
  const update = jest.fn(async ({ where, data }: any) => ({ id: where.id, ...data }));
  const prisma: any = {
    medicineRoutine: {
      findUnique: jest.fn(async () => (opts.routine === undefined ? ROUTINE : opts.routine)),
      findMany: jest.fn(async () => []),
    },
    healthSuggestion: {
      findFirst: jest.fn(async () => opts.draft ?? null),
      findUnique: jest.fn(async ({ where }: any) => ({ id: where.id, status: 'DRAFT' })),
      create,
      update,
    },
  };
  const ai = {
    isConfigured: jest.fn(() => opts.configured ?? true),
    generate: jest.fn(async () => (opts.generated === undefined ? GENERATED : opts.generated)),
  };
  return { service: new HealthSuggestionsService(prisma, ai as any), prisma, ai, create, update };
}

describe('HealthSuggestionsService.requestForRoutine (admin-initiated only)', () => {
  it('sends only that routine\'s medicine to the model and stores the response as a DRAFT linked to the routine', async () => {
    const { service, ai, create } = setup();
    await service.requestForRoutine('r1');
    expect(ai.generate).toHaveBeenCalledWith(['Metformin 500mg']);
    expect(create.mock.calls[0][0].data).toMatchObject({
      userId: 'u1', routineId: 'r1', status: 'DRAFT', sourceMedicines: 'Metformin 500mg', itemsEn: GENERATED.en, itemsBn: GENERATED.bn,
    });
    expect(create.mock.calls[0][0].data.publishedAt).toBeUndefined(); // never published by the request itself
  });

  it('re-requesting replaces the existing unpublished draft instead of piling up rows', async () => {
    const { service, create, update, prisma } = setup({ draft: { id: 'd1' } });
    await service.requestForRoutine('r1');
    expect(create).not.toHaveBeenCalled();
    expect(update.mock.calls[0][0].where).toEqual({ id: 'd1' });
    expect(prisma.healthSuggestion.findFirst.mock.calls[0][0].where).toMatchObject({ routineId: 'r1', status: 'DRAFT' });
  });

  it('model failure: 503, nothing stored', async () => {
    const { service, create, update } = setup({ generated: null });
    await expect(service.requestForRoutine('r1')).rejects.toThrow(ServiceUnavailableException);
    expect(create).not.toHaveBeenCalled();
    expect(update).not.toHaveBeenCalled();
  });

  it('AI not configured: 503 without a model call; unknown routine: 404', async () => {
    const a = setup({ configured: false });
    await expect(a.service.requestForRoutine('r1')).rejects.toThrow(ServiceUnavailableException);
    expect(a.ai.generate).not.toHaveBeenCalled();
    await expect(setup({ routine: null }).service.requestForRoutine('nope')).rejects.toThrow(NotFoundException);
  });

  it('a second click while the first is still generating is refused (one paid call)', async () => {
    const { service, ai } = setup();
    let release!: (v: any) => void;
    ai.generate.mockImplementationOnce(() => new Promise((r) => (release = r)));
    const first = service.requestForRoutine('r1');
    await new Promise((r) => setTimeout(r, 10));
    await expect(service.requestForRoutine('r1')).rejects.toThrow(ConflictException);
    release(GENERATED);
    await first;
    expect(ai.generate).toHaveBeenCalledTimes(1);
  });

  it('there is no automatic generator any more', () => {
    expect((setup().service as any).generateForUser).toBeUndefined();
  });
});

describe('HealthSuggestionsService routine panel', () => {
  it('lists routines with their latest suggestion and applies filters', async () => {
    const { service, prisma } = setup();
    await service.listRoutinesForAdmin({ userId: 'u1', active: true });
    const arg = prisma.medicineRoutine.findMany.mock.calls[0][0];
    expect(arg.where).toEqual({ userId: 'u1', active: true });
    expect(arg.include.healthSuggestions.take).toBe(1);
    expect(arg.take).toBe(200);
  });

  it('404 for an unknown routine', async () => {
    await expect(setup({ routine: null }).service.getRoutineForAdmin('x')).rejects.toThrow(NotFoundException);
  });
});
