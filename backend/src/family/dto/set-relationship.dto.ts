import { IsInt, IsOptional, Min } from 'class-validator';

/** PUT /family/members/:userId/relationship: a relationships id, or null to clear. */
export class SetRelationshipDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  relationshipId?: number | null;
}
