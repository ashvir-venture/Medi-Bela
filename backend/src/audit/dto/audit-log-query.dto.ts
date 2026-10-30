import { IsIn, IsOptional, IsString, IsUUID, Matches, MaxLength } from 'class-validator';
import { Role } from '@prisma/client';

const DAY = /^\d{4}-\d{2}-\d{2}$/;

/** GET /admin/audit-logs: 20 per page, newest first. */
export class AuditLogQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;

  /** Exact action, e.g. "prescription.reject" (choices from /admin/audit-logs/filters). */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  action?: string;

  @IsOptional()
  @IsUUID()
  actorId?: string;

  /** Who acted: staff (ADMIN / PHARMACIST) or a patient / caregiver (USER). */
  @IsOptional()
  @IsIn(Object.values(Role))
  actorRole?: Role;

  /** First day, inclusive (YYYY-MM-DD, app timezone). */
  @IsOptional()
  @Matches(DAY, { message: 'from must be YYYY-MM-DD' })
  from?: string;

  /** Last day, inclusive (YYYY-MM-DD, app timezone). */
  @IsOptional()
  @Matches(DAY, { message: 'to must be YYYY-MM-DD' })
  to?: string;
}
