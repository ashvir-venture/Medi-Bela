import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from './common/decorators/public.decorator';
import { CurrentUser } from './common/decorators/current-user.decorator';
import { effectiveTiming, OWN_TIMING_SELECT } from './common/config/reminder-timing';
import { PrismaService } from './prisma/prisma.service';

@Controller()
export class AppController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @SkipThrottle()
  @Get('health')
  getHealth() {
    return {
      status: 'ok',
      service: 'medi-bela backend',
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Reminder timings from .env (common/config/reminder-timing.ts) for the
   * app: it reschedules its reminders when they change. Signed-in users only.
   * Round 14: with the user's own timings on top (users.reminder*).
   */
  @Get('app-config')
  async getAppConfig(@CurrentUser('id') userId: string) {
    const own = await this.prisma.user.findUnique({ where: { id: userId }, select: OWN_TIMING_SELECT });
    return { reminders: effectiveTiming(own) };
  }
}
