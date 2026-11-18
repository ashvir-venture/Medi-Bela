import type { Request, Response } from 'express';
import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Req,
  Res,
  Patch,
  Post,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RefreshClient } from '@prisma/client';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ForgotPasswordDto, ResetPasswordDto } from './dto/forgot-password.dto';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { TokenPair } from './types/tokens.type';
import { clearRefreshCookie, readRefreshCookie, setRefreshCookie } from './refresh-cookie';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly config: ConfigService,
  ) {}

  @Public()
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  /** Round 18: the panel (`client: 'panel'`) gets its refresh token as an httpOnly cookie, never in the body. */
  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto, @Req() req: Request, @Res({ passthrough: true }) res: Response) {
    const result = await this.authService.login(dto, req.ip);
    if (dto.client === 'panel') return { ...result, tokens: this.toCookie(res, result.tokens) };
    return result;
  }

  /**
   * Round 18: a new access token and the next refresh token. The app sends
   * its refresh token in the body; the panel's comes in the cookie.
   */
  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: RefreshDto, @Req() req: Request, @Res({ passthrough: true }) res: Response) {
    const token = dto.refreshToken ?? readRefreshCookie(req) ?? '';
    try {
      const { tokens, client } = await this.authService.refresh(token);
      return { tokens: client === RefreshClient.PANEL ? this.toCookie(res, tokens) : tokens };
    } catch (e) {
      if (!dto.refreshToken) clearRefreshCookie(res, this.config);
      throw e;
    }
  }

  /** Public. Same response whether or not the number has an account. */
  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Body() dto: ForgotPasswordDto, @Req() req: Request) {
    return this.authService.forgotPassword(dto, req.ip);
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  async resetPassword(@Body() dto: ResetPasswordDto, @Req() req: Request) {
    await this.authService.resetPassword(dto, req.ip);
  }

  /**
   * Round 18: public, so it works after the access token ran out; holding the
   * refresh token is what lets a device sign itself out.
   */
  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Body() dto: RefreshDto, @Req() req: Request, @Res({ passthrough: true }) res: Response) {
    await this.authService.logout(dto.refreshToken ?? readRefreshCookie(req));
    clearRefreshCookie(res, this.config);
  }

  @Patch('change-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  async changePassword(
    @CurrentUser('id') userId: string,
    @CurrentUser('sid') sessionId: string | undefined,
    @Body() dto: ChangePasswordDto,
  ) {
    await this.authService.changePassword(userId, dto, sessionId);
  }

  /** Moves the panel's refresh token into the cookie and out of the response body. */
  private toCookie(res: Response, tokens: TokenPair): TokenPair {
    if (tokens.refreshToken && tokens.refreshExpiresAt) {
      setRefreshCookie(res, this.config, tokens.refreshToken, new Date(tokens.refreshExpiresAt));
    }
    return { accessToken: tokens.accessToken };
  }
}
