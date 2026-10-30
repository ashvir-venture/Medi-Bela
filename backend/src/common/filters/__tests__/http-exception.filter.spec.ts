import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { HttpExceptionFilter } from '../http-exception.filter';
import { ErrorCode, newErrorRef, withCode } from '../error-codes';

function run(exception: unknown, path = '/api/x') {
  let status = 0;
  let body: any;
  const res = {
    status: (s: number) => {
      status = s;
      return res;
    },
    json: (b: unknown) => {
      body = b;
    },
  };
  const host: any = {
    switchToHttp: () => ({
      getResponse: () => res,
      getRequest: () => ({ method: 'GET', url: `${path}?phone=01712345678`, path }),
    }),
  };
  new HttpExceptionFilter().catch(exception, host);
  return { status, body };
}

describe('HttpExceptionFilter codes and refs', () => {
  let logged: string[];
  beforeEach(() => {
    logged = [];
    jest.spyOn(Logger.prototype, 'error').mockImplementation((m: any) => {
      logged.push(String(m));
    });
  });
  afterEach(() => jest.restoreAllMocks());

  it('keeps message and adds the code for the status', () => {
    expect(run(new NotFoundException('Family member not found')).body).toMatchObject({
      statusCode: 404,
      message: 'Family member not found',
      code: 'NOT_FOUND',
    });
    expect(run(new ConflictException('x')).body.code).toBe('CONFLICT');
    expect(run(new HttpException('slow down', HttpStatus.TOO_MANY_REQUESTS)).body.code).toBe('RATE_LIMITED');
    expect(run(new ForbiddenException()).body.code).toBe('FORBIDDEN');
  });

  it('validation errors (a list of messages) are VALIDATION_FAILED; a plain 400 is BAD_REQUEST', () => {
    expect(run(new BadRequestException(['name must be longer'])).body.code).toBe('VALIDATION_FAILED');
    expect(run(new BadRequestException('Invalid cursor')).body.code).toBe('BAD_REQUEST');
  });

  it('a code set by the service wins', () => {
    const { body } = run(withCode(new ForbiddenException('Password is incorrect'), ErrorCode.PASSWORD_INCORRECT));
    expect(body).toMatchObject({ statusCode: 403, code: 'PASSWORD_INCORRECT', message: 'Password is incorrect' });
  });

  it('unexpected errors: 500, SERVER_ERROR, a ref that is in the log with the stack, nothing leaked', () => {
    const { status, body } = run(new Error('db password=secret in a stack trace'));
    expect(status).toBe(500);
    expect(body.code).toBe('SERVER_ERROR');
    expect(body.ref).toMatch(/^[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{2}$/);
    expect(body.message).toBe('Internal server error');
    expect(JSON.stringify(body)).not.toMatch(/secret/);
    expect(logged.some((l) => l.includes(`ref=${body.ref}`))).toBe(true);
  });

  it('the log line and the response path have no query string (it can hold a phone number)', () => {
    const { body } = run(new Error('boom'));
    expect(body.path).toBe('/api/x');
    expect(logged.join(' ')).not.toMatch(/01712345678/);
  });

  it('expected errors and maintenance carry no ref', () => {
    expect(run(new NotFoundException()).body).not.toHaveProperty('ref');
    const m = run(withCode(new ServiceUnavailableException('updating'), ErrorCode.MAINTENANCE));
    expect(m.status).toBe(503);
    expect(m.body.code).toBe('MAINTENANCE');
    expect(m.body).not.toHaveProperty('ref');
  });

  it('refs avoid look-alike characters', () => {
    for (let i = 0; i < 200; i++) expect(newErrorRef()).not.toMatch(/[01ILO]/);
  });
});
