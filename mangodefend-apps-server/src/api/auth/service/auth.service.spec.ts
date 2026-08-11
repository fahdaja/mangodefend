import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { UserService } from '../../users/service/user.service';
import { BcryptService } from '../../../common/hash/bcrypt.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { FirebaseService } from '../../../common/firebase/firebase.service';
import { MailService } from '../../../common/mail/mail.service';
import { RedisService } from '../../../common/redis/redis.service';
import { BadRequestException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { application_type, os_type } from '../../users/enum/devices.enum';

describe('AuthService - Adaptive 2FA & Verification OTP', () => {
  let authService: AuthService;
  let mockUserService: any;
  let mockBcryptService: any;
  let mockJwtService: any;
  let mockConfigService: any;
  let mockFirebaseService: any;
  let mockMailService: any;
  let mockRedisService: any;

  beforeEach(async () => {
    mockUserService = {
      findByEmail: jest.fn(),
      findDevice: jest.fn(),
      updatePassword: jest.fn(),
      markEmailAsVerified: jest.fn(),
      recordUserDevice: jest.fn(),
    };

    mockBcryptService = {
      hashPassword: jest.fn().mockResolvedValue('hashed_new_password'),
      comparePassword: jest.fn().mockResolvedValue(true),
    };

    mockJwtService = {
      signAsync: jest.fn().mockResolvedValue('mock_jwt_token'),
    };
    mockConfigService = {
      get: jest.fn().mockReturnValue('jwt_secret_key'),
    };
    mockFirebaseService = {};

    mockMailService = {
      sendForgotPasswordEmail: jest.fn().mockResolvedValue(true),
      sendVerificationEmail: jest.fn().mockResolvedValue(true),
      sendLoginOtpEmail: jest.fn().mockResolvedValue(true),
    };

    mockRedisService = {
      setResetToken: jest.fn().mockResolvedValue(undefined),
      getResetToken: jest.fn(),
      delResetToken: jest.fn().mockResolvedValue(undefined),
      setVerificationToken: jest.fn().mockResolvedValue(undefined),
      getVerificationToken: jest.fn(),
      delVerificationToken: jest.fn().mockResolvedValue(undefined),
      setLoginOtp: jest.fn().mockResolvedValue(undefined),
      getLoginOtp: jest.fn(),
      delLoginOtp: jest.fn().mockResolvedValue(undefined),
    };

    authService = new AuthService(
      mockUserService,
      mockBcryptService,
      mockJwtService,
      mockConfigService,
      mockFirebaseService,
      mockMailService,
      mockRedisService,
    );
  });

  describe('signIn (Adaptive 2FA Login Flow)', () => {
    const validDevice = {
      hardware_id: 'hw123',
      hostname: 'PC-Test',
      os_type: os_type.WINDOWS,
      app_type: application_type.DESKTOP,
    };

    it('should throw ForbiddenException if user email is not verified', async () => {
      mockUserService.findByEmail.mockResolvedValue({
        id: 1,
        email: 'unverified@example.com',
        password: 'hashed_password',
        is_email_verified: false,
      });

      await expect(
        authService.signIn({ email: 'unverified@example.com', password: 'password123' }, validDevice),
      ).rejects.toThrow(ForbiddenException);

      expect(mockRedisService.setVerificationToken).toHaveBeenCalledWith('unverified@example.com', expect.any(String), 300);
      expect(mockMailService.sendVerificationEmail).toHaveBeenCalledWith('unverified@example.com', expect.any(String));
    });

    it('should return pending_otp and send Login OTP email if logging in from a NEW unrecognized device', async () => {
      mockUserService.findByEmail.mockResolvedValue({
        id: 1,
        email: 'verified@example.com',
        password: 'hashed_password',
        is_email_verified: true,
      });
      mockUserService.findDevice.mockResolvedValue(null); // Unrecognized device

      const result = await authService.signIn(
        { email: 'verified@example.com', password: 'password123' },
        validDevice,
      );

      expect(result.status).toBe('pending_otp');
      expect(result.data.requires_otp).toBe(true);
      expect(result.data.is_new_device).toBe(true);
      expect(mockRedisService.setLoginOtp).toHaveBeenCalledWith('verified@example.com', expect.any(String), 600);
      expect(mockMailService.sendLoginOtpEmail).toHaveBeenCalledWith('verified@example.com', expect.any(String));
    });

    it('should directly return JWT access_token without OTP if logging in from a RECOGNIZED device', async () => {
      mockUserService.findByEmail.mockResolvedValue({
        id: 1,
        email: 'verified@example.com',
        password: 'hashed_password',
        is_email_verified: true,
      });
      mockUserService.findDevice.mockResolvedValue({
        id: 10,
        hardware_id: 'hw123',
      }); // Recognized device

      const result = await authService.signIn(
        { email: 'verified@example.com', password: 'password123' },
        validDevice,
      );

      expect(result.status).toBe('success');
      expect(result.data.access_token).toBe('mock_jwt_token');
      expect(mockRedisService.setLoginOtp).not.toHaveBeenCalled();
      expect(mockMailService.sendLoginOtpEmail).not.toHaveBeenCalled();
    });
  });

  describe('verifyRegistrationOtp', () => {
    it('should verify registration OTP and mark email as verified', async () => {
      mockRedisService.getVerificationToken.mockResolvedValue('654321');
      mockUserService.findByEmail.mockResolvedValue({ id: 1, email: 'user@example.com' });

      const result = await authService.verifyRegistrationOtp({ email: 'user@example.com', code: '654321' });

      expect(mockUserService.markEmailAsVerified).toHaveBeenCalledWith(1);
      expect(mockRedisService.delVerificationToken).toHaveBeenCalledWith('user@example.com');
      expect(result.status).toBe('success');
    });

    it('should throw BadRequestException if OTP code is invalid', async () => {
      mockRedisService.getVerificationToken.mockResolvedValue('111111');

      await expect(
        authService.verifyRegistrationOtp({ email: 'user@example.com', code: '999999' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('verifyLoginOtp', () => {
    it('should verify Login OTP, record device, and issue JWT access token', async () => {
      mockRedisService.getLoginOtp.mockResolvedValue('123456');
      mockUserService.findByEmail.mockResolvedValue({
        id: 1,
        email: 'verified@example.com',
        role: 'client',
        is_email_verified: true,
      });

      const result = await authService.verifyLoginOtp({
        email: 'verified@example.com',
        otp: '123456',
        device: {
          hardware_id: 'hw123',
          hostname: 'PC-Test',
          os_type: os_type.WINDOWS,
          app_type: application_type.DESKTOP,
        },
      });

      expect(mockUserService.recordUserDevice).toHaveBeenCalledWith(1, expect.any(Object));
      expect(mockRedisService.delLoginOtp).toHaveBeenCalledWith('verified@example.com');
      expect(result.status).toBe('success');
      expect(result.data.access_token).toBe('mock_jwt_token');
    });
  });
});
