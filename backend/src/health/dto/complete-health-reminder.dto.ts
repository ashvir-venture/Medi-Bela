import { IsISO8601, IsOptional } from 'class-validator';

export class CompleteHealthReminderDto {
  @IsOptional()
  @IsISO8601()
  completedAt?: string;
}
