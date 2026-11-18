import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { SmsService } from './sms.service';
import { RefreshTokenService } from './refresh-token.service';
import { RefreshTokenCleanupJob } from './refresh-token-cleanup.job';
import { JwtAccessStrategy } from './strategies/jwt-access.strategy';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }), 
    JwtModule.register({}),
  ],
  controllers: [AuthController],
  providers: [AuthService, SmsService, JwtAccessStrategy, RefreshTokenService, RefreshTokenCleanupJob],
  exports: [AuthService, PassportModule, RefreshTokenService],
})
export class AuthModule {}
