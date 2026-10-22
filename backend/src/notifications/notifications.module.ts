import { Global, Module } from '@nestjs/common';
import { DeviceTokensService } from './device-tokens.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PushDispatcherJob } from './push-dispatcher.job';
import { PushService } from './push.service';
import { TokenCryptoService } from './token-crypto.service';

@Global()
@Module({
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    DeviceTokensService,
    PushService,
    TokenCryptoService,
    PushDispatcherJob,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
