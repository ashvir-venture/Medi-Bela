import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CatalogService } from './catalog.service';
import {
  CatalogListQueryDto,
  CreateDoctorDto,
  CreateMedicineDto,
  CreateTestDto,
  SearchQueryDto,
  UpdateDoctorDto,
  UpdateMedicineDto,
} from './dto/catalog.dto';

/**
 * Doctor, medicine and test records. Both staff roles can read; only
 * pharmacists create or change them (admin is read-only).
 */
@Controller('catalog')
@Roles(Role.ADMIN, Role.PHARMACIST)
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  // --- Autosuggest ---

  @Get('doctors/search')
  searchDoctors(@Query() query: SearchQueryDto) {
    return this.catalog.searchDoctors(query.q);
  }

  /** Also open to patients: the app's "Add a medicine" form suggests from the catalog. */
  @Get('medicines/search')
  @Roles(Role.ADMIN, Role.PHARMACIST, Role.USER)
  searchMedicines(@Query() query: SearchQueryDto) {
    return this.catalog.searchMedicines(query.q);
  }

  @Get('tests/search')
  searchTests(@Query() query: SearchQueryDto) {
    return this.catalog.searchTests(query.q);
  }

  // --- Doctors ---

  // Admin responses add "Created by" (and the patient count on detail).

  @Get('doctors')
  listDoctors(@CurrentUser('role') role: Role, @Query() query: CatalogListQueryDto) {
    return this.catalog.listDoctors(query, role === Role.ADMIN);
  }

  @Get('doctors/:id')
  getDoctor(@CurrentUser('role') role: Role, @Param('id', ParseUUIDPipe) id: string) {
    return this.catalog.getDoctor(id, role === Role.ADMIN);
  }

  @Post('doctors')
  @Roles(Role.PHARMACIST)
  createDoctor(@CurrentUser('id') actorId: string, @Body() dto: CreateDoctorDto) {
    return this.catalog.createDoctor(actorId, dto);
  }

  @Patch('doctors/:id')
  @Roles(Role.PHARMACIST)
  updateDoctor(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateDoctorDto,
  ) {
    return this.catalog.updateDoctor(actorId, id, dto);
  }

  // --- Medicines ---

  @Get('medicines')
  listMedicines(@CurrentUser('role') role: Role, @Query() query: CatalogListQueryDto) {
    return this.catalog.listMedicines(query, role === Role.ADMIN);
  }

  @Get('medicines/:id')
  getMedicine(@CurrentUser('role') role: Role, @Param('id', ParseUUIDPipe) id: string) {
    return this.catalog.getMedicine(id, role === Role.ADMIN);
  }

  @Post('medicines')
  @Roles(Role.PHARMACIST)
  createMedicine(@CurrentUser('id') actorId: string, @Body() dto: CreateMedicineDto) {
    return this.catalog.createMedicine(actorId, dto);
  }

  @Patch('medicines/:id')
  @Roles(Role.PHARMACIST)
  updateMedicine(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMedicineDto,
  ) {
    return this.catalog.updateMedicine(actorId, id, dto);
  }

  // --- Tests ---

  @Post('tests')
  @Roles(Role.PHARMACIST)
  createTest(@Body() dto: CreateTestDto) {
    return this.catalog.createTest(dto);
  }
}
