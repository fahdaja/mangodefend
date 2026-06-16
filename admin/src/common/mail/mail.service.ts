import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private transporter: nodemailer.Transporter | null = null;
  private readonly logger = new Logger(MailService.name);
  private fromEmail = 'noreply@mangodefend.com';

  constructor(private readonly configService: ConfigService) {
    const host = this.configService.get<string>('SMTP_HOST');
    const port = this.configService.get<number>('SMTP_PORT') || 587;
    const user = this.configService.get<string>('SMTP_USER');
    const pass = this.configService.get<string>('SMTP_PASS');
    const from = this.configService.get<string>('SMTP_FROM');

    if (from) {
      this.fromEmail = from;
    }

    if (host && user && pass) {
      try {
        this.transporter = nodemailer.createTransport({
          host,
          port,
          secure: Number(port) === 465,
          auth: {
            user,
            pass,
          },
        });
        this.logger.log(`SMTP Mail Transporter initialized successfully at ${host}:${port}`);
      } catch (error) {
        this.logger.error('Failed to initialize SMTP transporter:', error);
      }
    } else {
      this.logger.warn(
        'SMTP configuration is missing. MailService will run in MOCK MODE (logging to console).',
      );
    }
  }

  async sendMail(to: string, subject: string, html: string): Promise<boolean> {
    if (this.transporter) {
      try {
        await this.transporter.sendMail({
          from: this.fromEmail,
          to,
          subject,
          html,
        });
        this.logger.log(`Email successfully sent to ${to}: "${subject}"`);
        return true;
      } catch (error) {
        this.logger.error(`Failed to send email to ${to}:`, error);
        return false;
      }
    } else {
      this.logger.log(
        `\n[MOCK EMAIL SENT]\nTo: ${to}\nSubject: ${subject}\nBody:\n${html}\n----------------------------------`,
      );
      return true;
    }
  }

  async sendReceiptEmail(data: {
    email: string;
    transactionId: number;
    planName: string;
    amount: number;
    durationDays: number;
    paymentMethod: string;
  }): Promise<boolean> {
    const formattedAmount = new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
    }).format(data.amount);

    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + data.durationDays);
    const formattedExpiry = expiryDate.toLocaleDateString('id-ID', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; padding: 24px; color: #333;">
        <div style="text-align: center; border-bottom: 2px solid #22c55e; padding-bottom: 16px; margin-bottom: 24px;">
          <h2 style="color: #16a34a; margin: 0;">MangoDefend Premium</h2>
          <p style="margin: 4px 0 0; color: #666; font-size: 14px;">Bukti Pembayaran & Aktivasi Langganan</p>
        </div>
        
        <p>Halo,</p>
        <p>Terima kasih atas pembayaran Anda! Transaksi Anda telah berhasil diverifikasi dan langganan Anda telah diaktifkan.</p>
        
        <div style="background-color: #f9fafb; border-radius: 6px; padding: 16px; margin: 20px 0;">
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 6px 0; color: #666;">ID Transaksi:</td>
              <td style="padding: 6px 0; text-align: right; font-weight: bold;">#${data.transactionId}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #666;">Paket Langganan:</td>
              <td style="padding: 6px 0; text-align: right; font-weight: bold; text-transform: capitalize; color: #16a34a;">${data.planName}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #666;">Metode Pembayaran:</td>
              <td style="padding: 6px 0; text-align: right; text-transform: uppercase;">${data.paymentMethod.replace('_', ' ')}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #666;">Jumlah Dibayar:</td>
              <td style="padding: 6px 0; text-align: right; font-weight: bold; font-size: 16px; color: #111827;">${formattedAmount}</td>
            </tr>
            <tr>
              <td style="padding: 6px 0; color: #666;">Durasi Paket:</td>
              <td style="padding: 6px 0; text-align: right;">${data.durationDays} Hari</td>
            </tr>
            <tr style="border-top: 1px solid #e5e7eb;">
              <td style="padding: 10px 0 6px; color: #666; font-weight: bold;">Berlaku Sampai:</td>
              <td style="padding: 10px 0 6px; text-align: right; font-weight: bold; color: #ef4444;">${formattedExpiry}</td>
            </tr>
          </table>
        </div>
        
        <p style="font-size: 13px; color: #666; line-height: 1.5;">
          Anda sekarang memiliki akses penuh ke fitur pendeteksian malware premium MangoDefend termasuk batas scan yang lebih besar dan update model antivirus otomatis.
        </p>
        
        <div style="text-align: center; margin-top: 32px; border-top: 1px solid #e0e0e0; padding-top: 16px; font-size: 12px; color: #999;">
          <p>© ${new Date().getFullYear()} MangoDefend Antivirus. Hak Cipta Dilindungi.</p>
        </div>
      </div>
    `;

    return this.sendMail(data.email, `[MangoDefend] Bukti Pembayaran Sukses - Paket ${data.planName.toUpperCase()}`, html);
  }
}
