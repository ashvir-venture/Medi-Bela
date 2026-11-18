import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { assertOwnUpload } from '../uploads/upload-purpose';

/**
 * Round 18 (client note point 1d): a photo of the medicine's strip / pack,
 * shown on the medicine's page and the full-screen reminder so older users
 * recognise it. Uploaded from the phone straight to Cloudinary (purpose
 * "pack"); stored as a private reference; read back as a 1-hour signed link.
 */
@Injectable()
export class PackPhotoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly cloudinary: CloudinaryService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  async set(acting: ActingFor, routineId: string, publicId: string | null) {
    const routine = await this.prisma.medicineRoutine.findUnique({ where: { id: routineId } });
    if (!routine || routine.userId !== acting.subjectId || !routine.active) throw new NotFoundException('Medicine not found');
    let url: string | null = null;
    if (publicId) {
      assertOwnUpload('pack', acting.subjectId, publicId);
      url = await this.cloudinary.confirmDirectUpload(publicId);
    }
    await this.prisma.medicineRoutine.update({ where: { id: routineId }, data: { packPhotoUrl: url } });
    if (routine.packPhotoUrl && routine.packPhotoUrl !== url) await this.cloudinary.deleteImageByUrl(routine.packPhotoUrl);
    await this.audit.record({
      actorId: acting.actorId,
      subjectUserId: acting.subjectId,
      action: 'routine.update',
      entityType: 'routine',
      entityId: routineId,
      before: { hasPackPhoto: !!routine.packPhotoUrl },
      after: { hasPackPhoto: !!url, byCaregiver: acting.byCaregiver },
    });
    await this.caregivers.notifyMember(acting, 'routine_updated', `${routineId}:pack:${Date.now()}`);
    return { hasPackPhoto: !!url, url: url ? this.cloudinary.signedImageUrl(url) : null };
  }

  async get(subjectId: string, routineId: string) {
    const routine = await this.prisma.medicineRoutine.findUnique({ where: { id: routineId }, select: { userId: true, packPhotoUrl: true } });
    if (!routine || routine.userId !== subjectId) throw new NotFoundException('Medicine not found');
    return { url: routine.packPhotoUrl ? this.cloudinary.signedImageUrl(routine.packPhotoUrl) : null };
  }
}
