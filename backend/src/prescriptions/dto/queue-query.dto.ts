import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { PrescriptionStatus } from '@prisma/client';

export const QUEUE_STATUSES = [...Object.values(PrescriptionStatus), 'ALL'] as const;
export type QueueStatus = (typeof QUEUE_STATUSES)[number];

export class QueueQueryDto {
  @IsOptional()
  @IsIn(QUEUE_STATUSES)
  status?: QueueStatus;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;
}
