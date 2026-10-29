import { CreatedBy } from '@/lib/api-client';

/**
 * "Created by" on admin catalog pages: the last pharmacist to save the
 * record, or the patient / caregiver whose self-added medicine created it.
 */
export function createdByLabel(createdBy: CreatedBy | null | undefined): string {
  if (!createdBy) return 'Unknown';
  return createdBy.role === 'USER' ? `${createdBy.name} (app user)` : createdBy.name;
}
