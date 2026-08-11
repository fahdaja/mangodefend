import {
  BadRequestException,
  Body,
  Controller,
  HttpCode,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from '../service/auth.service';
import {
  ForgotPasswordDto,
  LoginDto,
  ResendOtpDto,
  ResetPasswordDto,
  SessionDevice,
  SignOutDto,
  VerifyLoginOtpDto,
  VerifyRegistrationOtpDto,
} from '../dto/auth.dto';
import { FirebaseLoginDto } from '../dto/firebase-auth.dto';
import { AuthGuard } from '../guard/auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(200)
  async signIn(@Body() body: any) {
    const loginData: LoginDto = { email: body.email, password: body.password };
    const deviceData: SessionDevice = body.device;

    return this.authService.signIn(loginData, deviceData, 'client');
  }

  @Post('admin/login')
  @HttpCode(200)
  async adminSignIn(@Body() body: any) {
    const loginData: LoginDto = { email: body.email, password: body.password };
    const deviceData: SessionDevice = body.device;

    return this.authService.signIn(loginData, deviceData, 'admin');
  }

  @Post('firebase-login')
  @HttpCode(200)
  async firebaseSignIn(@Body() firebaseLoginDto: FirebaseLoginDto) {
    return this.authService.firebaseSignIn(firebaseLoginDto);
  }

  @Post('verify-registration-otp')
  @HttpCode(200)
  async verifyRegistrationOtp(@Body() dto: VerifyRegistrationOtpDto) {
    return this.authService.verifyRegistrationOtp(dto);
  }

  @Post('verify-login-otp')
  @HttpCode(200)
  async verifyLoginOtp(@Body() dto: VerifyLoginOtpDto) {
    return this.authService.verifyLoginOtp(dto);
  }

  @Post('resend-otp')
  @HttpCode(200)
  async resendOtp(@Body() dto: ResendOtpDto) {
    return this.authService.resendOtp(dto);
  }

  @Post('forgot-password')
  @HttpCode(200)
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto);
  }

  @Post('reset-password')
  @HttpCode(200)
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }

  @Post('logout')
  @UseGuards(AuthGuard)
  @HttpCode(200)
  async signOut(@Body() signOutDto: SignOutDto, @Req() req) {
    const userIdFromToken = req.user.id;

    return await this.authService.signOut({
      ...signOutDto,
      user_id: userIdFromToken,
    });
  }
}
