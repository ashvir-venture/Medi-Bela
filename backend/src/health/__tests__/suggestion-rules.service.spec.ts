import { NotFoundException } from '@nestjs/common';
import { SuggestionRulesService } from '../suggestion-rules.service';
import { CONDITION_TYPE_MEDICINE_NAME_CONTAINS } from '../lib/suggestion-rule-conditions';

function makeFakePrisma() {
  const rules = new Map<string, any>();
  return {
    _rules: rules,
    healthSuggestionRule: {
      findMany: jest.fn(async () => [...rules.values()]),
      findUnique: jest.fn(async ({ where }: any) => rules.get(where.id) ?? null),
      create: jest.fn(async ({ data }: any) => {
        const rule = { id: `rule-${rules.size + 1}`, ...data };
        rules.set(rule.id, rule);
        return rule;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const rule = rules.get(where.id);
        Object.assign(rule, data);
        return rule;
      }),
    },
  } as any;
}

describe('SuggestionRulesService', () => {
  let prisma: any;
  let ruleEvaluation: { evaluateRuleAcrossExistingMedicines: jest.Mock };
  let service: SuggestionRulesService;

  beforeEach(() => {
    prisma = makeFakePrisma();
    ruleEvaluation = { evaluateRuleAcrossExistingMedicines: jest.fn().mockResolvedValue(0) };
    service = new SuggestionRulesService(prisma, ruleEvaluation as any);
  });

  it('always creates a rule as an unpublished draft, regardless of what is requested', async () => {
    const rule = await service.create('admin-1', {
      name: 'Metformin check',
      conditionType: CONDITION_TYPE_MEDICINE_NAME_CONTAINS,
      conditionValue: 'metformin',
      suggestedAction: 'Blood sugar check',
    } as any);
    expect(rule.enabled).toBe(false);
    expect(rule.createdById).toBe('admin-1');
    expect(ruleEvaluation.evaluateRuleAcrossExistingMedicines).not.toHaveBeenCalled();
  });

  it('publish flips enabled=true and runs the backfill evaluation', async () => {
    const rule = await service.create('admin-1', {
      name: 'X',
      conditionType: CONDITION_TYPE_MEDICINE_NAME_CONTAINS,
      conditionValue: 'x',
      suggestedAction: 'Y',
    } as any);
    ruleEvaluation.evaluateRuleAcrossExistingMedicines.mockResolvedValue(3);

    const result = await service.publish(rule.id);

    expect(prisma._rules.get(rule.id).enabled).toBe(true);
    expect(ruleEvaluation.evaluateRuleAcrossExistingMedicines).toHaveBeenCalledWith(
      expect.objectContaining({ id: rule.id, enabled: true }),
    );
    expect(result.remindersCreated).toBe(3);
  });

  it('unpublish sets enabled=false without touching existing reminders (no evaluation call)', async () => {
    const rule = await service.create('admin-1', {
      name: 'X',
      conditionType: CONDITION_TYPE_MEDICINE_NAME_CONTAINS,
      conditionValue: 'x',
      suggestedAction: 'Y',
    } as any);
    await service.publish(rule.id);
    await service.unpublish(rule.id);

    expect(prisma._rules.get(rule.id).enabled).toBe(false);
    expect(ruleEvaluation.evaluateRuleAcrossExistingMedicines).toHaveBeenCalledTimes(1);
  });

  it('update never changes enabled, even if the caller tries to sneak it in', async () => {
    const rule = await service.create('admin-1', {
      name: 'X',
      conditionType: CONDITION_TYPE_MEDICINE_NAME_CONTAINS,
      conditionValue: 'x',
      suggestedAction: 'Y',
    } as any);
    await service.update(rule.id, { name: 'Renamed', enabled: true } as any);
    expect(prisma._rules.get(rule.id).enabled).toBe(false);
  });

  it('throws NotFoundException publishing/editing a nonexistent rule', async () => {
    await expect(service.publish('missing')).rejects.toThrow(NotFoundException);
    await expect(service.update('missing', { name: 'x' })).rejects.toThrow(NotFoundException);
  });
});
