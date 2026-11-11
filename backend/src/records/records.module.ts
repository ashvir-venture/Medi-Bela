import { Module } from '@nestjs/common';
import { FamilyModule } from '../family/family.module';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';
import { RecordsController } from './records.controller';
import { RecordsService } from './records.service';

/** Round 16: doctor visits, own tests and results, record-only prescriptions. */
@Module({
  imports: [FamilyModule],
  controllers: [RecordsController],
  providers: [RecordsService, CloudinaryService],
})
export class RecordsModule {}
