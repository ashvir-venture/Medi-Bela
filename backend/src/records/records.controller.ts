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
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';
import { prescriptionImageMulterOptions } from '../prescriptions/lib/prescription-image.storage';
import { RecordsService } from './records.service';
import {
  CreateAppointmentDto,
  CreateOwnTestDto,
  CreateRecordPrescriptionDto,
  DoctorSearchDto,
  NewDoctorDto,
  UpdateAppointmentDto,
  UpdateOwnTestDto,
  UpdateRecordPrescriptionDto,
} from './dto/records.dto';

/** Round 16. `?forUserId=` = the family caregiver acting for that member. */
@Controller('records')
export class RecordsController {
  constructor(
    private readonly records: RecordsService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  private acting(userId: string, forUserId?: string) {
    return this.caregivers.resolve(userId, forUserId);
  }

  @Get()
  async overview(
    @CurrentUser('id') userId: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.overview((await this.acting(userId, forUserId)).subjectId);
  }

  @Get('doctors/search')
  async searchDoctors(
    @CurrentUser('id') userId: string,
    @Query() query: DoctorSearchDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.searchDoctors((await this.acting(userId, forUserId)).subjectId, query.q);
  }

  @Post('my-doctors')
  async addMyDoctor(
    @CurrentUser('id') userId: string,
    @Body() dto: NewDoctorDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.addMyDoctor(await this.acting(userId, forUserId), dto);
  }

  // --- Appointments ---

  @Post('appointments')
  async createAppointment(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateAppointmentDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.createAppointment(await this.acting(userId, forUserId), dto);
  }

  @Patch('appointments/:id')
  async updateAppointment(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAppointmentDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.updateAppointment(await this.acting(userId, forUserId), id, dto);
  }

  @Delete('appointments/:id')
  async deleteAppointment(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.deleteAppointment(await this.acting(userId, forUserId), id);
  }

  // --- Own tests and results ---

  @Post('tests')
  async createTest(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateOwnTestDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.createTest(await this.acting(userId, forUserId), dto);
  }

  @Patch('tests/:id')
  async updateTest(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateOwnTestDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.updateTest(await this.acting(userId, forUserId), id, dto);
  }

  @Delete('tests/:id')
  async deleteTest(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.deleteTest(await this.acting(userId, forUserId), id);
  }

  @Post('tests/:id/photos')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(FileInterceptor('image', prescriptionImageMulterOptions))
  async addTestPhoto(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() image: Express.Multer.File | undefined,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    if (!image) throw new BadRequestException('A photo is required');
    return this.records.addPhoto(await this.acting(userId, forUserId), { ownTestId: id }, image.buffer, image.originalname);
  }

  // --- Record-only prescriptions ---

  @Post('prescriptions')
  async createPrescription(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateRecordPrescriptionDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.createPrescription(await this.acting(userId, forUserId), dto);
  }

  @Patch('prescriptions/:id')
  async updatePrescription(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRecordPrescriptionDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.updatePrescription(await this.acting(userId, forUserId), id, dto);
  }

  @Delete('prescriptions/:id')
  async deletePrescription(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.deletePrescription(await this.acting(userId, forUserId), id);
  }

  @Post('prescriptions/:id/photos')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(FileInterceptor('image', prescriptionImageMulterOptions))
  async addPrescriptionPhoto(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() image: Express.Multer.File | undefined,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    if (!image) throw new BadRequestException('A photo is required');
    return this.records.addPhoto(
      await this.acting(userId, forUserId),
      { recordPrescriptionId: id },
      image.buffer,
      image.originalname,
    );
  }

  @Delete('photos/:id')
  async deletePhoto(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.records.deletePhoto(await this.acting(userId, forUserId), id);
  }
}
