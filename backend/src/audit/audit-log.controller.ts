import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { AuditLogQueryDto } from './dto/audit-log-query.dto';
import { AuditLogService } from './audit-log.service';

/** Read-only audit log for admins. Nothing here writes; rows come from AuditService.record. */
@Controller('admin/audit-logs')
@Roles(Role.ADMIN)
export class AuditLogController {
  constructor(private readonly auditLog: AuditLogService) {}

  /** ?action=&actorId=&actorRole=&from=YYYY-MM-DD&to=YYYY-MM-DD&cursor= */
  @Get()
  list(@Query() query: AuditLogQueryDto) {
    return this.auditLog.list(query);
  }

  @Get('filters')
  filters() {
    return this.auditLog.filters();
  }

  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.auditLog.detail(id);
  }
}
