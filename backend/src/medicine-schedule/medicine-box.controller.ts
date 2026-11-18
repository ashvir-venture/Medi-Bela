import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Put, Query } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';
import { MedicineBoxService } from './medicine-box.service';
import { BoxExtraDto, SaveMedicineBoxDto, UpdateBoxExtraDto } from './dto/medicine-box.dto';

/**
 * `?forUserId=` = the family caregiver acting for that member (see and
 * refill their box). Ignore is the member's own action: it tells the caregiver.
 */
@Controller('medicine-box')
export class MedicineBoxController {
  constructor(
    private readonly box: MedicineBoxService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  @Get()
  async get(
    @CurrentUser('id') userId: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    const acting = await this.caregivers.resolve(userId, forUserId, 'view');
    return this.box.get(acting.subjectId);
  }

  @Put()
  async save(
    @CurrentUser('id') userId: string,
    @Body() dto: SaveMedicineBoxDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.box.save(await this.caregivers.resolve(userId, forUserId), dto);
  }

  /** Round 18: a box item with no reminder (a medicine at home, a care supply). */
  @Post('extras')
  async addExtra(
    @CurrentUser('id') userId: string,
    @Body() dto: BoxExtraDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.box.addExtra(await this.caregivers.resolve(userId, forUserId), dto);
  }

  @Patch('extras/:id')
  async updateExtra(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateBoxExtraDto,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.box.updateExtra(await this.caregivers.resolve(userId, forUserId), id, dto);
  }

  @Delete('extras/:id')
  async removeExtra(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('forUserId', new ParseUUIDPipe({ optional: true })) forUserId?: string,
  ) {
    return this.box.removeExtra(await this.caregivers.resolve(userId, forUserId), id);
  }

  @Post(':routineId/ignore')
  ignore(@CurrentUser('id') userId: string, @Param('routineId', ParseUUIDPipe) routineId: string) {
    return this.box.ignore(userId, routineId);
  }
}
