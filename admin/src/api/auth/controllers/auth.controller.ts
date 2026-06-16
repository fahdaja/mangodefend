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
import { AuthService } from '../services/auth.service';
import { LoginDto, SessionDevice, SignOutDto } from '../dto/auth.dto';
import { FirebaseLoginDto } from '../dto/firebase-auth.dto';
import { AuthGuard } from '../guards/auth.guard';

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
