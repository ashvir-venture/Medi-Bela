import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { codeForStatus, ErrorCode, newErrorRef } from './error-codes';

/**
 * Normalizes every error response (validation errors, thrown HttpExceptions,
 * and anything unexpected) into a single consistent JSON shape so API
 * consumers never have to branch on error format. Every response carries a
 * machine-readable `code` (see error-codes.ts); an unexpected error (5xx) also
 * carries a short `ref` that is logged with the stack trace, so support can
 * find it. The log line has the path only (no query string: it can hold a
 * phone number) and no request body.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';
    let error = 'Internal Server Error';
    let code: ErrorCode | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      code = (exception as HttpException & { errorCode?: ErrorCode }).errorCode;
      const body = exception.getResponse();
      if (typeof body === 'string') {
        message = body;
        error = exception.name;
      } else if (typeof body === 'object' && body !== null) {
        const asObj = body as Record<string, unknown>;
        message = (asObj.message as string | string[]) ?? exception.message;
        error = (asObj.error as string) ?? exception.name;
      }
    }

    const ref = status >= HttpStatus.INTERNAL_SERVER_ERROR && status !== HttpStatus.SERVICE_UNAVAILABLE ? newErrorRef() : null;
    if (ref) {
      // Unexpected: log full detail under the ref, never leak it to the client.
      this.logger.error(
        `ref=${ref} ${request.method} ${request.path} -> ${status}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    response.status(status).json({
      statusCode: status,
      error,
      message,
      code: code ?? codeForStatus(status, Array.isArray(message)),
      ...(ref ? { ref } : {}),
      path: request.path,
      timestamp: new Date().toISOString(),
    });
  }
}
