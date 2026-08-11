import { Injectable, Logger } from '@nestjs/common';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { FirebaseService } from '../../../common/firebase/firebase.service';
import { MailService } from '../../../common/mail/mail.service';

export class SendPushDto {
  @IsOptional()
  userId?: number;

  @IsString()
  @IsOptional()
  token?: string;

  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsString()
  @IsNotEmpty()
  body!: string;

  @IsOptional()
  data?: Record<string, string>;
}


@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    private readonly firebaseService: FirebaseService,
    private readonly mailService: MailService,
  ) {}

  async sendPushNotification(dto: SendPushDto): Promise<boolean> {
    if (dto.token) {
      try {
        await this.firebaseService.getMessaging().send({
          token: dto.token,
          notification: {
            title: dto.title,
            body: dto.body,
          },
          data: dto.data,
        });
        this.logger.log(`Push notification sent to token: ${dto.token.substring(0, 10)}...`);
        return true;
      } catch (err: any) {
        this.logger.warn(`Failed to send FCM push notification: ${err.message}`);
        return false;
      }
    } else {
      this.logger.log(`[Mock Push Notification] Title: "${dto.title}", Body: "${dto.body}"`);
      return true;
    }
  }

  async sendScanResultNotification(
    userId: number,
    summaryId: number,
    totalFiles: number,
    totalMalware: number,
    userEmail?: string,
  ): Promise<void> {
    const title = totalMalware > 0 ? '⚠️ Ancaman Ditemukan!' : '✅ Pemindaian Selesai';
    const body = totalMalware > 0
      ? `Hasil pemindaian #${summaryId}: ${totalMalware} ancaman malware terdeteksi dari ${totalFiles} file.`
      : `Hasil pemindaian #${summaryId}: ${totalFiles} file bersih, tidak ada ancaman terdeteksi.`;

    await this.sendPushNotification({
      userId,
      title,
      body,
      data: { summaryId: summaryId.toString(), totalMalware: totalMalware.toString() },
    });
  }

  async sendPaymentReceiptNotification(data: {
    email: string;
    transactionId: number;
    planName: string;
    amount: number;
    durationDays: number;
    paymentMethod: string;
  }): Promise<void> {
    try {
      await this.mailService.sendReceiptEmail(data);
      this.logger.log(`Receipt email dispatched to ${data.email} for Tx #${data.transactionId}`);
    } catch (err: any) {
      this.logger.error(`Failed to send receipt email: ${err.message}`);
    }
  }
}
