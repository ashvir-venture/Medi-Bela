import { Body, Controller, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { SignUploadDto } from './dto/sign-upload.dto';
import { uploadPublicId } from './upload-purpose';

/**
 * Round 18 (owner 2026-11-17): photos go from the phone straight to
 * Cloudinary. The phone asks here for one signed upload per photo, sends
 * the file to Cloudinary in the background, then hands the public id to the
 * endpoint that uses it (a prescription, a report page, a pack photo), which
 * checks it belongs to the user and is a real JPG / PNG under 10 MB.
 * `?forUserId=` = the caregiver for a member (the member's Manage permission).
 */
@Controller('uploads')
export class UploadsController {
  constructor(
    private readonly cloudinary: CloudinaryService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  @Post('sign')
  async sign(
    @CurrentUser('id') userId: string,
    @Body() dto: SignUploadDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    const acting = await this.caregivers.resolve(userId, forUserId, 'manage');
    return this.cloudinary.signDirectUpload(uploadPublicId(dto.purpose, acting.subjectId, randomUUID()));
  }
}
