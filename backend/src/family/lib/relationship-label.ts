import { Language } from '@prisma/client';

/**
 * Owner 2026-11-18: the relationship picked when inviting ("Baba", "Ma")
 * belongs to the person who picked it (family_members.relationToUserId).
 * They see it instead of the member's name; everyone else sees the name.
 */
export interface RelationshipRow {
  id: number;
  code: string;
  nameEn: string;
  nameBn: string;
}

export interface MemberRelation {
  relationToUserId: string | null;
  relationship: RelationshipRow | null;
}

/** The relationship to show to [viewerId], or null (show the name). */
export function relationshipFor(member: MemberRelation, viewerId: string): RelationshipRow | null {
  return member.relationship && member.relationToUserId === viewerId ? member.relationship : null;
}

/** What [viewerId] calls this member in a message: "Baba" / "বাবা", else the name. */
export function memberLabel(member: MemberRelation, name: string, viewerId: string, lang: Language): string {
  const r = relationshipFor(member, viewerId);
  if (!r) return name;
  return lang === Language.BN ? r.nameBn : r.nameEn;
}

/** The API shape (both languages; the app shows its own). */
export function presentRelationship(r: RelationshipRow | null) {
  return r ? { id: r.id, code: r.code, nameEn: r.nameEn, nameBn: r.nameBn } : null;
}

export const RELATION_SELECT = {
  relationToUserId: true,
  relationship: { select: { id: true, code: true, nameEn: true, nameBn: true } },
} as const;
