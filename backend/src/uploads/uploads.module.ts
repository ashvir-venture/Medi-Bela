import { Module } from '@nestjs/common';
import { FamilyModule } from '../family/family.module';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { UploadsController } from './uploads.controller';

@Module({
  imports: [FamilyModule],
  controllers: [UploadsController],
  providers: [CloudinaryService],
})
export class UploadsModule {}
