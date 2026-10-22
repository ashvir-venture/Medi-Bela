import { Language } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

/**
 * Body of `POST /assistant/conversations/:id/messages`.
 * The server loads the conversation context itself; the client never sends history.
 */
export class SendMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  message: string;

  /**
   * Client-generated UUID, created once per user message and re-sent unchanged
   * when retrying it. Makes retries and double-submits idempotent.
   */
  @IsUUID()
  clientMessageId: string;

  @IsOptional()
  @IsEnum(Language)
  language?: Language;
}
