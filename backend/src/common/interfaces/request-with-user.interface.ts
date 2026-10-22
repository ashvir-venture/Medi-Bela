import { Request } from 'express';
import { AuthenticatedUser } from './jwt-payload.interface';

export interface RequestWithUser extends Request {
  user: AuthenticatedUser;
}
