import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Put, Query } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CaregiverAccessService } from '../family/caregiver-access.service';
import { MedicineBoxService } from './medicine-box.service';
import { SaveMedicineBoxDto } from './dto/medicine-box.dto';

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
    const acting = await this.caregivers.resolve(userId, forUserId);
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

  @Post(':routineId/ignore')
  ignore(@CurrentUser('id') userId: string, @Param('routineId', ParseUUIDPipe) routineId: string) {
    return this.box.ignore(userId, routineId);
  }
}
