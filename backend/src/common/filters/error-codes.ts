import { HttpException, HttpStatus } from '@nestjs/common';
import { randomInt } from 'crypto';

/**
 * Machine-readable error codes sent next to `message` in every error
 * response. The apps map them to their own text (English / Bengali); an
 * unknown code falls back to a generic message. Services set a specific code
 * with `withCode`; anything else gets the one for its HTTP status.
 */
export const ErrorCode = {
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  BAD_REQUEST: 'BAD_REQUEST',
  UNAUTHORIZED: 'UNAUTHORIZED',
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  FORBIDDEN: 'FORBIDDEN',
  PASSWORD_INCORRECT: 'PASSWORD_INCORRECT',
  ACCOUNT_SUSPENDED: 'ACCOUNT_SUSPENDED',
  ACCOUNT_NOT_ACTIVE: 'ACCOUNT_NOT_ACTIVE',
  RESET_CODE_INVALID: 'RESET_CODE_INVALID',
  PHONE_TAKEN: 'PHONE_TAKEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  PAYLOAD_TOO_LARGE: 'PAYLOAD_TOO_LARGE',
  RATE_LIMITED: 'RATE_LIMITED',
  MAINTENANCE: 'MAINTENANCE',
  SERVER_ERROR: 'SERVER_ERROR',
} as const;

export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

/** `throw withCode(new ForbiddenException('Password is incorrect'), ErrorCode.PASSWORD_INCORRECT)` */
export function withCode<T extends HttpException>(exception: T, code: ErrorCode): T {
  (exception as T & { errorCode?: ErrorCode }).errorCode = code;
  return exception;
}

export function codeForStatus(status: number, validation: boolean): ErrorCode {
  if (status >= HttpStatus.INTERNAL_SERVER_ERROR && status !== HttpStatus.SERVICE_UNAVAILABLE) return ErrorCode.SERVER_ERROR;
  switch (status) {
    case HttpStatus.BAD_REQUEST:
      return validation ? ErrorCode.VALIDATION_FAILED : ErrorCode.BAD_REQUEST;
    case HttpStatus.UNAUTHORIZED:
      return ErrorCode.UNAUTHORIZED;
    case HttpStatus.FORBIDDEN:
      return ErrorCode.FORBIDDEN;
    case HttpStatus.NOT_FOUND:
      return ErrorCode.NOT_FOUND;
    case HttpStatus.CONFLICT:
      return ErrorCode.CONFLICT;
    case HttpStatus.PAYLOAD_TOO_LARGE:
      return ErrorCode.PAYLOAD_TOO_LARGE;
    case HttpStatus.TOO_MANY_REQUESTS:
      return ErrorCode.RATE_LIMITED;
    case HttpStatus.SERVICE_UNAVAILABLE:
      return ErrorCode.MAINTENANCE;
    default:
      return ErrorCode.BAD_REQUEST;
  }
}

// No 0/O, 1/I/L: easy to read out over the phone.
const REF_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

/** A short support reference for an unexpected error, e.g. "7KQ2-M9". */
export function newErrorRef(): string {
  const pick = (n: number) => Array.from({ length: n }, () => REF_ALPHABET[randomInt(REF_ALPHABET.length)]).join('');
  return `${pick(4)}-${pick(2)}`;
}
