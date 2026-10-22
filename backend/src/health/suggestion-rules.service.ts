import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSuggestionRuleDto } from './dto/create-suggestion-rule.dto';
import { UpdateSuggestionRuleDto } from './dto/update-suggestion-rule.dto';
import { RuleEvaluationService } from './rule-evaluation.service';

@Injectable()
export class SuggestionRulesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ruleEvaluation: RuleEvaluationService,
  ) {}

  async list() {
    return this.prisma.healthSuggestionRule.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async getDetail(id: string) {
    const rule = await this.prisma.healthSuggestionRule.findUnique({ where: { id } });
    if (!rule) throw new NotFoundException('Suggestion rule not found');
    return rule;
  }

  /**
   * Rules always start unpublished, regardless of what the request body
   * says — a rule only ever starts evaluating once an admin explicitly
   * hits Publish (see `publish` below). This is what makes "Publish" a
   * meaningful, deliberate action rather than something that can be
   * silently skipped.
   */
  async create(adminId: string, dto: CreateSuggestionRuleDto) {
    return this.prisma.healthSuggestionRule.create({
      data: {
        name: dto.name,
        description: dto.description,
        conditionType: dto.conditionType,
        conditionValue: dto.conditionValue,
        suggestedAction: dto.suggestedAction,
        enabled: false,
        createdById: adminId,
      },
    });
  }

  async update(id: string, dto: UpdateSuggestionRuleDto) {
    await this.getDetail(id);
    return this.prisma.healthSuggestionRule.update({
      where: { id },
      data: {
        name: dto.name,
        description: dto.description,
        conditionType: dto.conditionType,
        conditionValue: dto.conditionValue,
        suggestedAction: dto.suggestedAction,
        // `enabled` is intentionally not settable through the general
        // update endpoint — publishing/unpublishing is a distinct,
        // explicit action (see below), not a side effect of an edit.
      },
    });
  }

  /**
   * The admin-portal "Publish" action: flips the rule live, then
   * immediately evaluates it against every already-verified medicine on
   * record so matching users see the suggestion right away rather than
   * waiting for their next prescription. Returns how many reminders were
   * created by the backfill, so the admin UI can show something concrete
   * ("Published — 12 reminders created").
   */
  async publish(id: string) {
    const rule = await this.getDetail(id);
    const published = await this.prisma.healthSuggestionRule.update({
      where: { id },
      data: { enabled: true },
    });
    const reminderCount = await this.ruleEvaluation.evaluateRuleAcrossExistingMedicines(published);
    return { rule: published, remindersCreated: reminderCount };
  }

  /**
   * Stops the rule from matching anything going forward. Reminders it
   * already created are left alone — unpublishing is not a clinical
   * retraction, it's "stop suggesting this from now on".
   */
  async unpublish(id: string) {
    await this.getDetail(id);
    return this.prisma.healthSuggestionRule.update({ where: { id }, data: { enabled: false } });
  }
}
