import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { FamilyModule } from './family/family.module';
import { PrescriptionsModule } from './prescriptions/prescriptions.module';
import { MedicineScheduleModule } from './medicine-schedule/medicine-schedule.module';
import { HealthModule } from './health/health.module';
import { NoticesModule } from './notices/notices.module';
import { AdminModule } from './admin/admin.module';
import { AssistantModule } from './assistant/assistant.module';
import { NotificationsModule } from './notifications/notifications.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { rateLimitOptions } from './common/rate-limit/rate-limit.config';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) =>
        rateLimitOptions({
          RATE_LIMIT_ENABLED: config.get<string>('RATE_LIMIT_ENABLED'),
          RATE_LIMIT_USER_PER_MINUTE: config.get<string>('RATE_LIMIT_USER_PER_MINUTE'),
          RATE_LIMIT_IP_PER_MINUTE: config.get<string>('RATE_LIMIT_IP_PER_MINUTE'),
          NODE_ENV: config.get<string>('NODE_ENV'),
        }),
    }),
    PrismaModule,
    NotificationsModule,
    AuthModule,
    UsersModule,
    FamilyModule,
    PrescriptionsModule,
    MedicineScheduleModule,
    HealthModule,
    NoticesModule,
    AdminModule,
    AssistantModule,
  ],
  controllers: [AppController],
  providers: [
    // Every route requires a valid access token unless marked @Public().
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    // Runs after JwtAuthGuard; only restricts routes with @Roles(...).
    { provide: APP_GUARD, useClass: RolesGuard },
    // Global rate limit (see rate-limit.config.ts). Registered last so it
    // sees request.user and never counts requests rejected with 401.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
  ],
})
export class AppModule {}
