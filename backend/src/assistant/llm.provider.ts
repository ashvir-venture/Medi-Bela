import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

/**
 * The only thing in the codebase that talks to the AI provider for the
 * assistant. Same OpenAI-compatible `/chat/completions` convention and env
 * vars as the existing suggestion generator, so there is one provider
 * config to manage:
 *   LLM_API_BASE_URL, LLM_API_KEY, LLM_MODEL
 *
 * Pure transport: it returns text or null. It has no access to the database
 * and no tools/functions, so whatever the model "wants", it can only produce
 * words.
 */
@Injectable()
export class LlmProvider {
  private readonly logger = new Logger(LlmProvider.name);
  private static readonly TIMEOUT_MS = 20_000;

  constructor(private readonly config: ConfigService) { }

  isConfigured(): boolean {
    return Boolean(this.config.get<string>('LLM_API_BASE_URL') && this.config.get<string>('LLM_API_KEY'));
  }

  async complete(system: string, turns: ChatTurn[]): Promise<string | null> {
    if (!this.isConfigured()) return null;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), LlmProvider.TIMEOUT_MS);
    try {
      const baseUrl = this.config.get<string>('LLM_API_BASE_URL')!.replace(/\/+$/, '');
      const response = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.config.get<string>('LLM_API_KEY')}`,
        },
        body: JSON.stringify({
          model: this.config.get<string>('LLM_MODEL', 'gpt-4o-mini'),
          temperature: 0.2,
          // ~80 words; Bengali needs more tokens per word, hence the headroom.
          max_tokens: 320,
          messages: [{ role: 'system', content: system }, ...turns],
        }),
      });
      if (!response.ok) {
        const errorText = await response.text();
        this.logger.warn(
          `AI provider responded ${response.status}: ${errorText.slice(0, 300)}`,
        );
        return null;
      }
      const body = (await response.json()) as { choices?: { message?: { content?: string }; finish_reason?: string }[] };
      const choice = body.choices?.[0];
      const text = choice?.message?.content?.trim();
      if (!text) return null;
      // Hit the token cap mid-sentence: keep only whole sentences rather than a cut-off reply.
      return choice?.finish_reason === 'length' ? trimToSentence(text) : text;
    } catch (err) {
      // Never log prompts or replies: they can contain health information.
      this.logger.warn(`AI provider call failed: ${(err as Error).name}`);
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
}

/** Cuts a truncated reply back to its last complete sentence (keeps it whole if there is none). */
export function trimToSentence(text: string): string {
  const end = Math.max(text.lastIndexOf('. '), text.lastIndexOf('? '), text.lastIndexOf('! '), text.lastIndexOf('।'));
  const last = /[.?!।]$/.test(text) ? text.length : end + 1;
  return last > 0 ? text.slice(0, last).trim() : text;
}
