// International-ish phone format: optional leading +, 7-15 digits total.
// Tighten to a BD-specific pattern (e.g. /^\+8801[3-9]\d{8}$/) once the
// target market for rollout is confirmed.
export const PHONE_REGEX = /^\+?[1-9]\d{6,14}$/;
