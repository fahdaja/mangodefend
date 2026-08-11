import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;
  private isConnected = false;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const host = this.configService.get<string>('REDIS_HOST', 'localhost');
    const port = this.configService.get<number>('REDIS_PORT', 6379);
    const password = this.configService.get<string>('REDIS_PASSWORD', '');

    try {
      this.client = new Redis({
        host,
        port: Number(port),
        password: password || undefined,
        lazyConnect: true,
        maxRetriesPerRequest: 3,
        retryStrategy(times) {
          if (times > 3) return null;
          return Math.min(times * 100, 3000);
        },
      });

      this.client.on('connect', () => {
        this.isConnected = true;
        this.logger.log(`Connected to Redis at ${host}:${port}`);
      });

      this.client.on('error', (err) => {
        this.logger.warn(`Redis connection error: ${err.message}`);
        this.isConnected = false;
      });

      this.client.connect().catch((err) => {
        this.logger.warn(`Initial Redis connection failed (running fallback in-memory mode): ${err.message}`);
      });
    } catch (err: any) {
      this.logger.warn(`Failed to initialize Redis client: ${err.message}`);
    }
  }

  async onModuleDestroy() {
    if (this.client && this.isConnected) {
      await this.client.quit();
    }
  }

  getClient(): Redis | null {
    return this.isConnected ? this.client : null;
  }

  // --- Fingerprint Cache ---
  async getFingerprint(sha256: string): Promise<boolean | null> {
    if (!this.client || !this.isConnected) return null;
    try {
      const val = await this.client.get(`fingerprint:${sha256}`);
      if (val === null) return null;
      return val === '1' || val === 'true';
    } catch (err: any) {
      this.logger.warn(`Redis getFingerprint error: ${err.message}`);
      return null;
    }
  }

  async setFingerprint(sha256: string, isMalware: boolean, ttlSeconds: number = 86400 * 7): Promise<void> {
    if (!this.client || !this.isConnected) return;
    try {
      await this.client.set(`fingerprint:${sha256}`, isMalware ? '1' : '0', 'EX', ttlSeconds);
    } catch (err: any) {
      this.logger.warn(`Redis setFingerprint error: ${err.message}`);
    }
  }

  // --- Quota Limits Cache ---
  async getDailyScanCount(userId: number, scanType: string): Promise<number | null> {
    if (!this.client || !this.isConnected) return null;
    try {
      const today = new Date().toISOString().split('T')[0];
      const val = await this.client.get(`quota:${userId}:${scanType}:${today}`);
      return val ? parseInt(val, 10) : 0;
    } catch (err: any) {
      this.logger.warn(`Redis getDailyScanCount error: ${err.message}`);
      return null;
    }
  }

  async incrementDailyScanCount(userId: number, scanType: string): Promise<number | null> {
    if (!this.client || !this.isConnected) return null;
    try {
      const today = new Date().toISOString().split('T')[0];
      const key = `quota:${userId}:${scanType}:${today}`;
      const count = await this.client.incr(key);
      if (count === 1) {
        await this.client.expire(key, 86400);
      }
      return count;
    } catch (err: any) {
      this.logger.warn(`Redis incrementDailyScanCount error: ${err.message}`);
      return null;
    }
  }

  // --- Device Limits Cache ---
  async getActiveDeviceCount(userId: number): Promise<number | null> {
    if (!this.client || !this.isConnected) return null;
    try {
      const val = await this.client.get(`device_count:${userId}`);
      return val ? parseInt(val, 10) : null;
    } catch (err: any) {
      this.logger.warn(`Redis getActiveDeviceCount error: ${err.message}`);
      return null;
    }
  }

  async setActiveDeviceCount(userId: number, count: number, ttlSeconds: number = 3600): Promise<void> {
    if (!this.client || !this.isConnected) return;
    try {
      await this.client.set(`device_count:${userId}`, count.toString(), 'EX', ttlSeconds);
    } catch (err: any) {
      this.logger.warn(`Redis setActiveDeviceCount error: ${err.message}`);
    }
  }

  private resetTokenFallback = new Map<string, { token: string; expiresAt: number }>();
  private verificationTokenFallback = new Map<string, { token: string; expiresAt: number }>();
  private loginOtpFallback = new Map<string, { otp: string; expiresAt: number }>();

  async invalidateDeviceCount(userId: number): Promise<void> {
    if (!this.client || !this.isConnected) return;
    try {
      await this.client.del(`device_count:${userId}`);
    } catch (err: any) {
      this.logger.warn(`Redis invalidateDeviceCount error: ${err.message}`);
    }
  }

  // --- Password Reset Token Cache ---
  async setResetToken(email: string, token: string, ttlSeconds: number = 900): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.set(`reset_token:${email}`, token, 'EX', ttlSeconds);
        return;
      } catch (err: any) {
        this.logger.warn(`Redis setResetToken error: ${err.message}`);
      }
    }
    this.resetTokenFallback.set(email, {
      token,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async getResetToken(email: string): Promise<string | null> {
    if (this.client && this.isConnected) {
      try {
        return await this.client.get(`reset_token:${email}`);
      } catch (err: any) {
        this.logger.warn(`Redis getResetToken error: ${err.message}`);
      }
    }
    const record = this.resetTokenFallback.get(email);
    if (!record) return null;
    if (Date.now() > record.expiresAt) {
      this.resetTokenFallback.delete(email);
      return null;
    }
    return record.token;
  }

  async delResetToken(email: string): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.del(`reset_token:${email}`);
      } catch (err: any) {
        this.logger.warn(`Redis delResetToken error: ${err.message}`);
      }
    }
    this.resetTokenFallback.delete(email);
  }

  // --- Email Registration Verification Token Cache ---
  async setVerificationToken(email: string, token: string, ttlSeconds: number = 300): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.set(`verify_token:${email}`, token, 'EX', ttlSeconds);
        return;
      } catch (err: any) {
        this.logger.warn(`Redis setVerificationToken error: ${err.message}`);
      }
    }
    this.verificationTokenFallback.set(email, {
      token,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async getVerificationToken(email: string): Promise<string | null> {
    if (this.client && this.isConnected) {
      try {
        return await this.client.get(`verify_token:${email}`);
      } catch (err: any) {
        this.logger.warn(`Redis getVerificationToken error: ${err.message}`);
      }
    }
    const record = this.verificationTokenFallback.get(email);
    if (!record) return null;
    if (Date.now() > record.expiresAt) {
      this.verificationTokenFallback.delete(email);
      return null;
    }
    return record.token;
  }

  async delVerificationToken(email: string): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.del(`verify_token:${email}`);
      } catch (err: any) {
        this.logger.warn(`Redis delVerificationToken error: ${err.message}`);
      }
    }
    this.verificationTokenFallback.delete(email);
  }

  // --- Login 2FA OTP Cache ---
  async setLoginOtp(email: string, otp: string, ttlSeconds: number = 600): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.set(`login_otp:${email}`, otp, 'EX', ttlSeconds);
        return;
      } catch (err: any) {
        this.logger.warn(`Redis setLoginOtp error: ${err.message}`);
      }
    }
    this.loginOtpFallback.set(email, {
      otp,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async getLoginOtp(email: string): Promise<string | null> {
    if (this.client && this.isConnected) {
      try {
        return await this.client.get(`login_otp:${email}`);
      } catch (err: any) {
        this.logger.warn(`Redis getLoginOtp error: ${err.message}`);
      }
    }
    const record = this.loginOtpFallback.get(email);
    if (!record) return null;
    if (Date.now() > record.expiresAt) {
      this.loginOtpFallback.delete(email);
      return null;
    }
    return record.otp;
  }

  async delLoginOtp(email: string): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.del(`login_otp:${email}`);
      } catch (err: any) {
        this.logger.warn(`Redis delLoginOtp error: ${err.message}`);
      }
    }
    this.loginOtpFallback.delete(email);
  }
}
