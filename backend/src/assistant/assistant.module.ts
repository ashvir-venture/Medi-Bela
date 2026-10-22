import { Module } from '@nestjs/common';
import { AssistantController } from './assistant.controller';
import { AssistantService } from './assistant.service';
import { LlmProvider } from './llm.provider';

@Module({
  controllers: [AssistantController],
  providers: [AssistantService, LlmProvider],
})
export class AssistantModule {}
