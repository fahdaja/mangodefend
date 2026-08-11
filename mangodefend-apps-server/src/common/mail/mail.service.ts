import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendVerificationEmail(email: string, code: string): Promise<void> {
    this.logger.log(`[MailService] Sending registration verification OTP (${code}) to ${email}`);
  }

  async sendLoginOtpEmail(email: string, otp: string): Promise<void> {
    this.logger.log(`[MailService] Sending 2FA login OTP (${otp}) to ${email}`);
  }

  async sendForgotPasswordEmail(email: string, token: string): Promise<void> {
    this.logger.log(`[MailService] Sending password reset OTP (${token}) to ${email}`);
  }

  async sendReceiptEmail(data: {
    email: string;
    transactionId: number;
    planName: string;
    amount: number;
    durationDays: number;
    paymentMethod: string;
  }): Promise<void> {
    this.logger.log(
      `[MailService] Sending payment receipt for Tx #${data.transactionId} (${data.planName}) to ${data.email}`
    );
  }
}
