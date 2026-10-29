import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface AuditEntry {
  actorId: string | null;
  subjectUserId?: string | null;
  /** e.g. "prescription.prepare", "doctor.update" */
  action: string;
  entityType: string;
  entityId?: string | null;
  before?: Prisma.InputJsonValue;
  after?: Prisma.InputJsonValue;
}

/**
 * Append-only AuditLog writer. Callers pass only what changed (status,
 * catalog fields); never secrets, phone numbers or health readings.
 * Pass the transaction client when the change itself runs in one, so the
 * audit row commits (or rolls back) with it.
 */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry, tx?: Prisma.TransactionClient) {
    const client = tx ?? this.prisma;
    await client.auditLog.create({
      data: {
        actorId: entry.actorId,
        subjectUserId: entry.subjectUserId ?? null,
        action: entry.action,
        entityType: entry.entityType,
        entityId: entry.entityId ?? null,
        before: entry.before,
        after: entry.after,
      },
    });
  }
}
