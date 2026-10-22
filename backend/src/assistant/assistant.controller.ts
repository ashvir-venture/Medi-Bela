import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AssistantService } from './assistant.service';
import { SendMessageDto } from './dto/chat.dto';

/**
 * Authenticated users only (global JWT guard). The user id always comes from
 * the verified token, never from the request, and every operation is scoped
 * to it: another user's conversation is indistinguishable from a missing one (404).
 */
@Controller('assistant')
export class AssistantController {
  constructor(private readonly assistant: AssistantService) {}

  @Get('conversations')
  list(@CurrentUser('id') userId: string) {
    return this.assistant.listConversations(userId);
  }

  @Post('conversations')
  create(@CurrentUser('id') userId: string) {
    return this.assistant.createConversation(userId);
  }

  @Get('conversations/:id')
  get(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.assistant.getConversation(userId, id);
  }

  @Post('conversations/:id/messages')
  @HttpCode(HttpStatus.OK)
  send(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.assistant.sendMessage(userId, id, dto);
  }

  @Delete('conversations/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    await this.assistant.deleteConversation(userId, id);
  }
}
