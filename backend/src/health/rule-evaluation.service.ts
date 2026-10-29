import { Injectable, Logger } from '@nestjs/common';
import { HealthSuggestionRule, PrescriptionMedicine } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CONDITION_TYPE_MEDICINE_NAME_CONTAINS } from './lib/suggestion-rule-conditions';

/**
 * Evaluates `HealthSuggestionRule`s against verified `PrescriptionMedicine`
 * rows and creates matching `HealthReminder`s. Fully deterministic --
 * no AI/LLM is involved in whether a custom rule fires or what it says.
 * (AI-generated suggestions are a separate feature; see
 * `AiSuggestionService` / `HealthSuggestion`.)
 *
 * Two entry points, matching the two moments a rule needs to run:
 *
 *  - `evaluateForMedicine`: called automatically once per verified
 *    medicine when a prescription is completed, checking it against
 *    whatever rules are *already published* (`enabled`).
 *  - `evaluateRuleAcrossExistingMedicines`: called explicitly by
 *    `SuggestionRulesService.publish()` for exactly one rule, the moment
 *    an admin hits Publish.
 *
 * Safe to re-run either way:
 *  - A rule never invents a reminder's content -- the reminder's title is
 *    exactly the rule's `suggestedAction` text, set up by an admin.
 *  - Dedup key is (userId, sourceRuleId): once a given rule has produced
 *    a reminder for a user, re-evaluating never creates a second one.
 */
@Injectable()
export class RuleEvaluationService {
  private readonly logger = new Logger(RuleEvaluationService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Called once per verified medicine when a prescription is completed. */
  async evaluateForMedicine(userId: string, medicine: PrescriptionMedicine): Promise<void> {
    const enabledRules = await this.prisma.healthSuggestionRule.findMany({
      where: { enabled: true },
    });

    for (const rule of enabledRules) {
      await this.evaluateOne(rule, userId, medicine);
    }
  }

  /**
   * Backfill run for a single rule at publish time: checks it against
   * every medicine that's already verified on a completed prescription,
   * system-wide.
   */
  async evaluateRuleAcrossExistingMedicines(rule: HealthSuggestionRule): Promise<number> {
    const verifiedMedicines = await this.prisma.prescriptionMedicine.findMany({
      where: { verified: true, prescription: { status: 'ACTIVE' } },
      include: { prescription: { select: { userId: true } } },
    });

    let created = 0;
    for (const medicine of verifiedMedicines) {
      const didCreate = await this.evaluateOne(rule, medicine.prescription.userId, medicine);
      if (didCreate) created++;
    }
    this.logger.log(
      `Published rule ${rule.id} ("${rule.name}"): created ${created} reminder(s) across ${verifiedMedicines.length} existing verified medicine(s)`,
    );
    return created;
  }

  /** Evaluates one rule against one medicine; creates a reminder on a match. Returns whether it created one. */
  private async evaluateOne(
    rule: HealthSuggestionRule,
    userId: string,
    medicine: PrescriptionMedicine,
  ): Promise<boolean> {
    const isMatch = this.matches(rule.conditionType, rule.conditionValue, medicine);
    if (!isMatch) return false;

    const alreadyExists = await this.prisma.healthReminder.findFirst({
      where: { userId, sourceRuleId: rule.id },
      select: { id: true },
    });
    if (alreadyExists) {
      this.logger.debug(`Rule ${rule.id} already produced a reminder for user ${userId}; skipping`);
      return false;
    }

    await this.prisma.healthReminder.create({
      data: {
        userId,
        sourceRuleId: rule.id,
        title: rule.suggestedAction,
        description: `Suggested because you were prescribed ${medicine.medicineName}. This is not medical advice -- please consult a doctor or pharmacist.`,
        scheduledAt: new Date(),
      },
    });
    return true;
  }

  private matches(
    conditionType: string,
    conditionValue: string,
    medicine: PrescriptionMedicine,
  ): boolean {
    switch (conditionType) {
      case CONDITION_TYPE_MEDICINE_NAME_CONTAINS:
        // conditionValue may list several keywords separated by commas
        // ("metformin, glipizide"): that is how an admin expresses a medicine
        // category without any model deciding what belongs in it.
        return conditionValue
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .filter(Boolean)
          .some((keyword) => medicine.medicineName.toLowerCase().includes(keyword));
      default:
        return false;
    }
  }
}
