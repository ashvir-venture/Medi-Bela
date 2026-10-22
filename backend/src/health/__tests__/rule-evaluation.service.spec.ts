import { RuleEvaluationService } from '../rule-evaluation.service';
import { CONDITION_TYPE_MEDICINE_NAME_CONTAINS } from '../lib/suggestion-rule-conditions';

function makeFakePrisma() {
  const rules = new Map<string, any>();
  const reminders: any[] = [];
  const verifiedMedicines: any[] = [];

  return {
    _rules: rules,
    _reminders: reminders,
    _verifiedMedicines: verifiedMedicines,
    healthSuggestionRule: {
      findMany: jest.fn(async ({ where }: any) =>
        [...rules.values()].filter((r) => (where?.enabled === undefined ? true : r.enabled === where.enabled)),
      ),
    },
    healthReminder: {
      findFirst: jest.fn(async ({ where }: any) =>
        reminders.find((r) => r.userId === where.userId && r.sourceRuleId === where.sourceRuleId) ?? null,
      ),
      create: jest.fn(async ({ data }: any) => {
        const record = { id: `reminder-${reminders.length + 1}`, ...data };
        reminders.push(record);
        return record;
      }),
    },
    prescriptionMedicine: {
      findMany: jest.fn(async () => verifiedMedicines),
    },
  } as any;
}

function makeRule(overrides: Partial<any> = {}): any {
  return {
    id: 'rule-1',
    name: 'Metformin → blood sugar check',
    conditionType: CONDITION_TYPE_MEDICINE_NAME_CONTAINS,
    conditionValue: 'metformin',
    suggestedAction: 'Blood sugar check',
    enabled: true,
    ...overrides,
  };
}

function makeMedicine(overrides: Partial<any> = {}): any {
  return { id: 'med-1', medicineName: 'Metformin 500mg', ...overrides };
}

describe('RuleEvaluationService', () => {
  let prisma: any;
  let service: RuleEvaluationService;

  beforeEach(() => {
    prisma = makeFakePrisma();
    service = new RuleEvaluationService(prisma);
  });

  it('creates a health reminder when a medicine matches an enabled rule (case-insensitive)', async () => {
    prisma._rules.set('rule-1', makeRule());
    await service.evaluateForMedicine('user-1', makeMedicine({ medicineName: 'METFORMIN 500mg' }));

    expect(prisma._reminders).toHaveLength(1);
    expect(prisma._reminders[0]).toMatchObject({
      userId: 'user-1',
      sourceRuleId: 'rule-1',
      title: 'Blood sugar check',
    });
  });

  it('supports a category as comma-separated keywords (any one matches), ignoring blanks/spaces', async () => {
    prisma._rules.set('rule-1', makeRule({ conditionValue: ' glipizide , metformin ,, ' }));
    await service.evaluateForMedicine('user-1', makeMedicine({ medicineName: 'Metformin 500mg' }));
    await service.evaluateForMedicine('user-2', makeMedicine({ medicineName: 'GLIPIZIDE 5mg' }));
    await service.evaluateForMedicine('user-3', makeMedicine({ medicineName: 'Amlodipine 5mg' }));
    expect(prisma._reminders.map((r: any) => r.userId).sort()).toEqual(['user-1', 'user-2']);
  });

  it('a value made only of separators never matches everything', async () => {
    prisma._rules.set('rule-1', makeRule({ conditionValue: ' , ,' }));
    await service.evaluateForMedicine('user-1', makeMedicine());
    expect(prisma._reminders).toHaveLength(0);
  });

  it('does not create a reminder when the medicine does not match', async () => {
    prisma._rules.set('rule-1', makeRule());
    await service.evaluateForMedicine('user-1', makeMedicine({ medicineName: 'Paracetamol' }));
    expect(prisma._reminders).toHaveLength(0);
  });

  it('ignores disabled rules', async () => {
    prisma._rules.set('rule-1', makeRule({ enabled: false }));
    await service.evaluateForMedicine('user-1', makeMedicine());
    expect(prisma._reminders).toHaveLength(0);
  });

  it('never invents content: the reminder title is exactly the rule\'s suggestedAction', async () => {
    prisma._rules.set('rule-1', makeRule({ suggestedAction: 'Exact admin-authored text' }));
    await service.evaluateForMedicine('user-1', makeMedicine());
    expect(prisma._reminders[0].title).toBe('Exact admin-authored text');
  });

  it('is idempotent: re-evaluating the same user/rule never creates a duplicate reminder', async () => {
    prisma._rules.set('rule-1', makeRule());
    await service.evaluateForMedicine('user-1', makeMedicine());
    await service.evaluateForMedicine('user-1', makeMedicine()); // e.g. a second matching medicine
    expect(prisma._reminders).toHaveLength(1);
  });

  it('evaluates independently per user', async () => {
    prisma._rules.set('rule-1', makeRule());
    await service.evaluateForMedicine('user-1', makeMedicine());
    await service.evaluateForMedicine('user-2', makeMedicine());
    expect(prisma._reminders).toHaveLength(2);
  });

  it('never matches an unsupported/unknown conditionType (fail closed)', async () => {
    prisma._rules.set('rule-1', makeRule({ conditionType: 'SOMETHING_MADE_UP' }));
    await service.evaluateForMedicine('user-1', makeMedicine());
    expect(prisma._reminders).toHaveLength(0);
  });

  describe('evaluateRuleAcrossExistingMedicines (publish-time backfill)', () => {
    it('creates reminders for every matching verified medicine, across users', async () => {
      prisma._verifiedMedicines.push(
        { id: 'm1', medicineName: 'Metformin 500mg', prescription: { userId: 'user-1' } },
        { id: 'm2', medicineName: 'Paracetamol', prescription: { userId: 'user-1' } },
        { id: 'm3', medicineName: 'Metformin XR', prescription: { userId: 'user-2' } },
      );
      const rule = makeRule({ enabled: true });

      const created = await service.evaluateRuleAcrossExistingMedicines(rule);

      expect(created).toBe(2);
      expect(prisma._reminders.map((r: any) => r.userId).sort()).toEqual(['user-1', 'user-2']);
    });

    it('does not double-create for a user who already has a reminder from this rule', async () => {
      prisma._verifiedMedicines.push(
        { id: 'm1', medicineName: 'Metformin 500mg', prescription: { userId: 'user-1' } },
      );
      prisma._reminders.push({ id: 'existing', userId: 'user-1', sourceRuleId: 'rule-1' });

      const created = await service.evaluateRuleAcrossExistingMedicines(makeRule());

      expect(created).toBe(0);
      expect(prisma._reminders).toHaveLength(1);
    });

    it('returns 0 when nothing matches', async () => {
      prisma._verifiedMedicines.push(
        { id: 'm1', medicineName: 'Paracetamol', prescription: { userId: 'user-1' } },
      );
      expect(await service.evaluateRuleAcrossExistingMedicines(makeRule())).toBe(0);
    });
  });
});

