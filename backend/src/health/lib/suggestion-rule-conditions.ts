/**
 * `HealthSuggestionRule.conditionType`/`conditionValue` are plain strings
 * in the schema (not a DB enum) so new condition kinds can be added
 * without a migration. Deliberately deterministic only — no AI/LLM
 * matching here. Generative, AI-written suggestions are a separate
 * feature (`HealthSuggestion` / `AiSuggestionService`); a custom rule
 * always fires from exact, admin-authored logic so its output is fully
 * predictable and reviewable.
 */
export const CONDITION_TYPE_MEDICINE_NAME_CONTAINS = 'MEDICINE_NAME_CONTAINS';

export const SUPPORTED_CONDITION_TYPES = [CONDITION_TYPE_MEDICINE_NAME_CONTAINS] as const;
