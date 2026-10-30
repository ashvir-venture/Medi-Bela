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
      findUnique: jest.fn(async ({ where }: any) => ({ id: where.id, userId: 'u1', status: 'DRAFT' })),
      create,
      update,
    },
  };
  prisma.$transaction = jest.fn(async (fn: any) => fn(prisma));
  const audit = { record: jest.fn(async () => undefined) };
  const ai = {
    isConfigured: jest.fn(() => opts.configured ?? true),
    generate: jest.fn(async () => (opts.generated === undefined ? GENERATED : opts.generated)),
  };
  return { service: new HealthSuggestionsService(prisma, ai as any, audit as any), prisma, ai, audit, create, update };
}

describe('HealthSuggestionsService.requestForRoutine (pharmacist-initiated only)', () => {
  it('sends only that routine\'s medicine to the model and stores the response as a DRAFT linked to the routine', async () => {
    const { service, ai, create } = setup();
    await service.requestForRoutine('ph1', 'r1');
    expect(ai.generate).toHaveBeenCalledWith(['Metformin 500mg']);
    expect(create.mock.calls[0][0].data).toMatchObject({
      userId: 'u1', routineId: 'r1', status: 'DRAFT', sourceMedicines: 'Metformin 500mg', itemsEn: GENERATED.en, itemsBn: GENERATED.bn,
    });
    expect(create.mock.calls[0][0].data.publishedAt).toBeUndefined(); // never published by the request itself
  });

  it('re-requesting replaces the existing unpublished draft instead of piling up rows', async () => {
    const { service, create, update, prisma } = setup({ draft: { id: 'd1' } });
    await service.requestForRoutine('ph1', 'r1');
    expect(create).not.toHaveBeenCalled();
    expect(update.mock.calls[0][0].where).toEqual({ id: 'd1' });
    expect(prisma.healthSuggestion.findFirst.mock.calls[0][0].where).toMatchObject({ routineId: 'r1', status: 'DRAFT' });
  });

  it('model failure: 503, nothing stored', async () => {
    const { service, create, update } = setup({ generated: null });
    await expect(service.requestForRoutine('ph1', 'r1')).rejects.toThrow(ServiceUnavailableException);
    expect(create).not.toHaveBeenCalled();
    expect(update).not.toHaveBeenCalled();
  });

  it('AI not configured: 503 without a model call; unknown routine: 404', async () => {
    const a = setup({ configured: false });
    await expect(a.service.requestForRoutine('ph1', 'r1')).rejects.toThrow(ServiceUnavailableException);
    expect(a.ai.generate).not.toHaveBeenCalled();
    await expect(setup({ routine: null }).service.requestForRoutine('ph1', 'nope')).rejects.toThrow(NotFoundException);
  });

  it('a second click while the first is still generating is refused (one paid call)', async () => {
    const { service, ai } = setup();
    let release!: (v: any) => void;
    ai.generate.mockImplementationOnce(() => new Promise((r) => (release = r)));
    const first = service.requestForRoutine('ph1', 'r1');
    await new Promise((r) => setTimeout(r, 10));
    await expect(service.requestForRoutine('ph1', 'r1')).rejects.toThrow(ConflictException);
    release(GENERATED);
    await first;
    expect(ai.generate).toHaveBeenCalledTimes(1);
  });

  it('there is no automatic generator any more', () => {
    expect((setup().service as any).generateForUser).toBeUndefined();
  });
});

describe('HealthSuggestionsService routine panel', () => {
  it('pages routines 20 at a time (keyset), with their latest suggestion and the filters', async () => {
    const { service, prisma } = setup();
    await service.listRoutines({ active: true, q: 'met' });
    const arg = prisma.medicineRoutine.findMany.mock.calls[0][0];
    expect(arg.where.AND[0]).toMatchObject({ active: true });
    expect(arg.where.AND[0].OR[0]).toEqual({ medicineName: { contains: 'met', mode: 'insensitive' } });
    expect(arg.include.healthSuggestions.take).toBe(1);
    expect(arg.take).toBe(21);
    expect(arg.orderBy).toEqual([{ createdAt: 'desc' }, { id: 'desc' }]);
  });

  it('returns nextCursor only when there is another page', async () => {
    const { service, prisma } = setup();
    const rows = Array.from({ length: 21 }, (_, i) => ({ id: `r${i}`, createdAt: new Date(2026, 0, 1, 0, 0, 30 - i) }));
    prisma.medicineRoutine.findMany.mockResolvedValueOnce(rows);
    const page = await service.listRoutines({});
    expect(page.items).toHaveLength(20);
    expect(page.nextCursor).toEqual(expect.any(String));
    prisma.medicineRoutine.findMany.mockResolvedValueOnce(rows.slice(0, 3));
    expect((await service.listRoutines({})).nextCursor).toBeNull();
  });

  it('404 for an unknown routine', async () => {
    await expect(setup({ routine: null }).service.getRoutine('x')).rejects.toThrow(NotFoundException);
  });
});

describe('HealthSuggestionsService review (audited)', () => {
  it('lists suggestions 20 per page with a status filter', async () => {
    const { service, prisma } = setup();
    prisma.healthSuggestion.findMany = jest.fn(async () => []);
    await service.list({ status: 'DRAFT' as any });
    const arg = prisma.healthSuggestion.findMany.mock.calls[0][0];
    expect(arg.where.AND[0]).toEqual({ status: 'DRAFT' });
    expect(arg.take).toBe(21);
  });

  it('publish records who published, and an audit row with the status change only', async () => {
    const { service, update, audit } = setup();
    await service.publish('ph1', 's1');
    expect(update.mock.calls[0][0].data).toMatchObject({ status: 'PUBLISHED', publishedById: 'ph1' });
    expect(audit.record).toHaveBeenCalledWith(
      {
        actorId: 'ph1', subjectUserId: 'u1', action: 'health_suggestion.publish', entityType: 'health_suggestion', entityId: 's1',
        before: { status: 'DRAFT' }, after: { status: 'PUBLISHED' },
      },
      expect.anything(),
    );
  });

  it('unpublish and edits are audited too; a request is audited once it is stored', async () => {
    const { service, audit } = setup();
    await service.unpublish('ph1', 's1');
    await service.update('ph1', 's1', { itemsEn: [], itemsBn: [] } as any);
    await service.requestForRoutine('ph1', 'r1');
    const actions = audit.record.mock.calls.map((c: any[]) => c[0].action);
    expect(actions).toEqual(['health_suggestion.unpublish', 'health_suggestion.update', 'health_suggestion.request']);
    // Never the suggestion text.
    for (const [entry] of audit.record.mock.calls as any[]) expect(JSON.stringify(entry)).not.toContain('HbA1c');
  });

  it('a failed model call writes no audit row', async () => {
    const { service, audit } = setup({ generated: null });
    await expect(service.requestForRoutine('ph1', 'r1')).rejects.toThrow(ServiceUnavailableException);
    expect(audit.record).not.toHaveBeenCalled();
  });
});
