import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateHealthRecordDto } from './dto/create-health-record.dto';
import { UpdateHealthRecordDto } from './dto/update-health-record.dto';

@Injectable()
export class HealthRecordsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateHealthRecordDto) {
    // Idempotent for offline retries: the same (user, clientId) returns the
    // record created the first time instead of a duplicate.
    if (dto.clientId) {
      const existing = await this.prisma.healthRecord.findUnique({
        where: { userId_clientId: { userId, clientId: dto.clientId } },
      });
      if (existing) return existing;
    }
    try {
      return await this.createRow(userId, dto);
    } catch (err) {
      // Two concurrent retries: the loser reads the winner's row.
      if (dto.clientId && err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        const existing = await this.prisma.healthRecord.findUnique({
          where: { userId_clientId: { userId, clientId: dto.clientId } },
        });
        if (existing) return existing;
      }
      throw err;
    }
  }

  private createRow(userId: string, dto: CreateHealthRecordDto) {
    return this.prisma.healthRecord.create({
      data: {
        userId,
        clientId: dto.clientId,
        type: dto.type,
        value: dto.value,
        unit: dto.unit,
        notes: dto.notes,
        recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
      },
    });
  }

  async list(userId: string) {
    return this.prisma.healthRecord.findMany({
      where: { userId },
      orderBy: { recordedAt: 'desc' },
    });
  }

  async getDetail(userId: string, id: string) {
    const record = await this.prisma.healthRecord.findUnique({ where: { id } });
    if (!record || record.userId !== userId) {
      throw new NotFoundException('Health record not found');
    }
    return record;
  }

  /**
   * Corrects a mistaken entry (e.g. a typo'd value). Deliberately narrow:
   * only `value`/`unit`/`notes` are editable — `type` and `recordedAt`
   * are not, since a health record is a point-in-time log entry, not a
   * mutable "current status" row; changing what was measured or when
   * would misrepresent history rather than correct it.
   */
  async update(userId: string, id: string, dto: UpdateHealthRecordDto) {
    await this.getDetail(userId, id); // ownership check
    return this.prisma.healthRecord.update({
      where: { id },
      data: { value: dto.value, unit: dto.unit, notes: dto.notes },
    });
  }
}
