import { IsISO8601, IsOptional } from 'class-validator';

/**
 * `takenAt` is optional and client-supplied on purpose: when a dose is
 * marked TAKEN while offline, the moment that matters is when the user
 * actually tapped the button, not whenever the sync engine eventually
 * gets a connection. If omitted, the server uses its own current time.
 */
export class MarkDoseTakenDto {
  @IsOptional()
  @IsISO8601()
  takenAt?: string;
}
