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
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import  { Role } from '@prisma/client';
import { PrescriptionsService } from './prescriptions.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { CreatePrescriptionDto } from './dto/create-prescription.dto';
import { SaveMedicinesDto } from './dto/save-medicines.dto';
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
    return this.prescriptions.create(userId, image.buffer, image.originalname, dto.clientId);
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

  @Get('admin/pending')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  listPending() {
    return this.prescriptions.listPending();
  }

  @Get('admin/:id')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  getForAdmin(@Param('id', ParseUUIDPipe) id: string) {
    return this.prescriptions.getDetailForAdmin(id);
  }

  @Put('admin/:id/medicines')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  saveMedicines(
    @CurrentUser('id') adminId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SaveMedicinesDto,
  ) {
    return this.prescriptions.saveMedicines(adminId, id, dto);
  }

  @Delete('admin/:id/medicines/:medicineId')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  removeMedicine(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('medicineId', ParseUUIDPipe) medicineId: string,
  ) {
    return this.prescriptions.removeMedicine(id, medicineId);
  }

  @Post('admin/:id/complete')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  complete(@CurrentUser('id') adminId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.prescriptions.complete(adminId, id);
  }

  @Post('admin/:id/reject')
  @Roles(Role.ADMIN, Role.PHARMACIST)
  reject(
    @CurrentUser('id') adminId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectPrescriptionDto,
  ) {
    return this.prescriptions.reject(adminId, id, dto.rejectionReason);
  }
}
