import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Role } from '@prisma/client';
import { PrescriptionsService } from './prescriptions.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { CreatePrescriptionDto } from './dto/create-prescription.dto';
import { SaveMedicinesDto } from './dto/save-medicines.dto';
import { SavePrescriptionDetailsDto } from './dto/save-details.dto';
import { QueueQueryDto } from './dto/queue-query.dto';
import { RejectPrescriptionDto } from './dto/reject-prescription.dto';
import { prescriptionImageMulterOptions } from './lib/prescription-image.storage';
import { PrescriptionImageUrlInterceptor } from './lib/prescription-image-url.interceptor';
import 'multer';

@Controller('prescriptions')
@UseInterceptors(PrescriptionImageUrlInterceptor)
export class PrescriptionsController {
  constructor(private readonly prescriptions: PrescriptionsService) {}

  // --- User ---------------------------------------------------------

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(FileInterceptor('image', prescriptionImageMulterOptions))
  upload(
    @CurrentUser('id') userId: string,
    @UploadedFile() image: Express.Multer.File | undefined,
    @Body() dto: CreatePrescriptionDto,
  ) {
    if (!image) {
      throw new BadRequestException('Prescription image is required');
    }
    return this.prescriptions.create(
      userId,
      image.buffer,
      image.originalname,
      dto.clientId,
      dto.previousPrescriptionId,
    );
  }

  @Get('mine')
  getMine(@CurrentUser('id') userId: string) {
    return this.prescriptions.getMyHistory(userId);
  }

  @Get(':id')
  getOne(@CurrentUser('id') userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.prescriptions.getMyPrescriptionDetail(userId, id);
  }

  // --- Admin / Pharmacist --------------------------------------------
  // Both staff roles can read; only pharmacists prepare or reject.

  @Get('admin/pending')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  listPending() {
    return this.prescriptions.listPending();
  }

  /** Paginated queue: ?status=PENDING|AWAITING_CONFIRMATION|...|ALL&cursor= */
  @Get('admin/queue')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  listQueue(@Query() query: QueueQueryDto) {
    return this.prescriptions.listQueue(query.status, query.cursor);
  }

  @Get('admin/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  getForAdmin(@Param('id', ParseUUIDPipe) id: string) {
    return this.prescriptions.getDetailForAdmin(id);
  }

  @Put('admin/:id/details')
  @Roles(Role.PHARMACIST)
  saveDetails(
    @CurrentUser('id') pharmacistId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SavePrescriptionDetailsDto,
  ) {
    return this.prescriptions.saveDetails(pharmacistId, id, dto);
  }

  @Put('admin/:id/medicines')
  @Roles(Role.PHARMACIST)
  saveMedicines(
    @CurrentUser('id') pharmacistId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SaveMedicinesDto,
  ) {
    return this.prescriptions.saveMedicines(pharmacistId, id, dto);
  }

  @Delete('admin/:id/medicines/:medicineId')
  @Roles(Role.PHARMACIST)
  removeMedicine(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('medicineId', ParseUUIDPipe) medicineId: string,
  ) {
    return this.prescriptions.removeMedicine(id, medicineId);
  }

  /** Sends the prepared prescription to the user (AWAITING_CONFIRMATION). */
  @Post('admin/:id/complete')
  @Roles(Role.PHARMACIST)
  complete(@CurrentUser('id') pharmacistId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.prescriptions.complete(pharmacistId, id);
  }

  @Post('admin/:id/reject')
  @Roles(Role.PHARMACIST)
  reject(
    @CurrentUser('id') pharmacistId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectPrescriptionDto,
  ) {
    return this.prescriptions.reject(pharmacistId, id, dto.rejectionReason);
  }
}
