import { IsBoolean } from 'class-validator';

/** Round 18: what a member lets the family caregiver do. Manage implies View. */
export class CaregiverPermissionsDto {
  @IsBoolean()
  view: boolean;

  @IsBoolean()
  manage: boolean;
}
