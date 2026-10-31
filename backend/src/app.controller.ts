import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from './common/decorators/public.decorator';
import { reminderTiming } from './common/config/reminder-timing';

@Controller()
export class AppController {
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
   */
  @Get('app-config')
  getAppConfig() {
    return { reminders: reminderTiming() };
  }
}
