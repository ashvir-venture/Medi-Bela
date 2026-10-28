import {
  CanActivate,
  Controller,
  ExecutionContext,
  Get,
  INestApplication,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { SkipThrottle, ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import request from 'supertest';
import { HttpExceptionFilter } from '../../filters/http-exception.filter';
import { rateLimitOptions } from '../rate-limit.config';

/**
 * Stands in for JwtAuthGuard: `x-user` signs the request in as that user id,
 * `x-bad-token` is rejected with 401, anything else is a public request.
 */
@Injectable()
class FakeAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    if (req.headers['x-bad-token']) throw new UnauthorizedException();
    if (req.headers['x-user']) req.user = { id: req.headers['x-user'] };
    return true;
  }
}

@Controller()
class TestController {
  @Get('a')
  a() {
    return { ok: true };
  }

  @Get('b')
  b() {
    return { ok: true };
  }

  @SkipThrottle()
  @Get('health')
  health() {
    return { ok: true };
  }
}

async function makeApp(): Promise<INestApplication> {
  const moduleRef = await Test.createTestingModule({
    imports: [
      ThrottlerModule.forRoot(
        rateLimitOptions({
          RATE_LIMIT_ENABLED: 'true',
          RATE_LIMIT_USER_PER_MINUTE: '3',
          RATE_LIMIT_IP_PER_MINUTE: '2',
        }),
      ),
    ],
    controllers: [TestController],
    providers: [
      { provide: APP_GUARD, useClass: FakeAuthGuard },
      { provide: APP_GUARD, useClass: ThrottlerGuard },
      { provide: APP_FILTER, useClass: HttpExceptionFilter },
    ],
  }).compile();
  const app = moduleRef.createNestApplication();
  await app.init();
  return app;
}

describe('global rate limit', () => {
  let app: INestApplication;

  beforeEach(async () => {
    app = await makeApp();
  });

  afterEach(() => app.close());

  it('limits public requests per IP across all routes, with 429 and Retry-After', async () => {
    const server = app.getHttpServer();
    await request(server).get('/a').expect(200);
    await request(server).get('/b').expect(200);

    const res = await request(server).get('/a').expect(429);
    expect(Number(res.headers['retry-after'])).toBeGreaterThan(0);
    expect(res.body.statusCode).toBe(429);
  });

  it('counts signed-in requests per user, not per shared IP', async () => {
    const server = app.getHttpServer();
    for (let i = 0; i < 3; i++) {
      await request(server).get('/a').set('x-user', 'u1').expect(200);
    }
    await request(server).get('/b').set('x-user', 'u1').expect(429);

    // Same IP, different user: own bucket. Public bucket untouched as well.
    await request(server).get('/a').set('x-user', 'u2').expect(200);
    await request(server).get('/a').expect(200);
  });

  it('does not count requests rejected with 401', async () => {
    const server = app.getHttpServer();
    for (let i = 0; i < 5; i++) {
      await request(server).get('/a').set('x-bad-token', '1').expect(401);
    }
    await request(server).get('/a').expect(200);
  });

  it('never limits routes marked @SkipThrottle (health)', async () => {
    const server = app.getHttpServer();
    for (let i = 0; i < 5; i++) {
      await request(server).get('/health').expect(200);
    }
  });
});

describe('rateLimitOptions', () => {
  const skipIf = (env: Parameters<typeof rateLimitOptions>[0]) => {
    const options = rateLimitOptions(env);
    if (Array.isArray(options)) throw new Error('expected object options');
    return options.skipIf!({} as ExecutionContext);
  };

  it('is off under Jest by default and on elsewhere', () => {
    expect(skipIf({ NODE_ENV: 'test' })).toBe(true);
    expect(skipIf({ NODE_ENV: 'production' })).toBe(false);
    expect(skipIf({})).toBe(false);
  });

  it('can be switched explicitly', () => {
    expect(skipIf({ NODE_ENV: 'production', RATE_LIMIT_ENABLED: 'false' })).toBe(true);
    expect(skipIf({ NODE_ENV: 'test', RATE_LIMIT_ENABLED: 'true' })).toBe(false);
  });
});
