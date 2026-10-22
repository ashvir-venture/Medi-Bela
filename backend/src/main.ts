import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { PrismaService } from './prisma/prisma.service';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const config = app.get(ConfigService);

  // Behind a load balancer/reverse proxy, trust its X-Forwarded-For so the
  // login throttle sees real client IPs. Set TRUST_PROXY=1 in that case.
  if (config.get<string>('TRUST_PROXY')) app.set('trust proxy', Number(config.get('TRUST_PROXY')) || 1);

  // Prescription images are uploaded straight to Cloudinary (see
  // CloudinaryService) and served from there, so no local static
  // directory is needed for them anymore.

  app.use(
    helmet({
      // Cross-Origin-Resource-Policy defaults to same-origin, which would
      // block the Flutter app (a different origin) from loading images
      // served above.
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  const corsOrigins = config
    .get<string>('CORS_ORIGINS', '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  app.enableCors({
    origin: corsOrigins.length > 0 ? corsOrigins : true,
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strip properties not declared on the DTO
      forbidNonWhitelisted: true, // reject requests with unknown properties
      transform: true, // turn plain payloads into DTO class instances
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  app.setGlobalPrefix('api');

  const prismaService = app.get(PrismaService);
  await prismaService.enableShutdownHooks(app);

  const port = config.get<number>('PORT', 3001);
  await app.listen(port, '0.0.0.0');
  // eslint-disable-next-line no-console
  console.log(`Medi-bela backend listening on port ${port}`);
}
bootstrap();
