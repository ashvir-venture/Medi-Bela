import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { Role } from '@prisma/client';
import { SuggestionRulesService } from './suggestion-rules.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { CreateSuggestionRuleDto } from './dto/create-suggestion-rule.dto';
import { UpdateSuggestionRuleDto } from './dto/update-suggestion-rule.dto';

@Controller('admin/suggestion-rules')
@Roles(Role.ADMIN, Role.PHARMACIST)
export class SuggestionRulesController {
  constructor(private readonly rules: SuggestionRulesService) {}

  @Get()
  list() {
    return this.rules.list();
  }

  @Get(':id')
  getDetail(@Param('id', ParseUUIDPipe) id: string) {
    return this.rules.getDetail(id);
  }

  @Post()
  create(@CurrentUser('id') adminId: string, @Body() dto: CreateSuggestionRuleDto) {
    return this.rules.create(adminId, dto);
  }

  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateSuggestionRuleDto) {
    return this.rules.update(id, dto);
  }

  @Post(':id/publish')
  publish(@Param('id', ParseUUIDPipe) id: string) {
    return this.rules.publish(id);
  }

  @Post(':id/unpublish')
  unpublish(@Param('id', ParseUUIDPipe) id: string) {
    return this.rules.unpublish(id);
  }
}
