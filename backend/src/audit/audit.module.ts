import { Global, Module } from '@nestjs/common';
import { AuditService } from './audit.service';
import { AuditLogController } from './audit-log.controller';
import { AuditLogService } from './audit-log.service';

@Global()
@Module({
  controllers: [AuditLogController],
  providers: [AuditService, AuditLogService],
  exports: [AuditService],
})
export class AuditModule {}
