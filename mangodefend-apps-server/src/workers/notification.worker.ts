import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { RabbitMQService, QUEUES } from '../common/rabbitmq/rabbitmq.service';
import { NotificationService } from '../api/notifications/service/notification.service';

export interface NotificationJobPayload {
  type: 'SCAN_RESULT' | 'PAYMENT_RECEIPT' | 'CUSTOM_PUSH';
  userId?: number;
  email?: string;
  summaryId?: number;
  totalScanned?: number;
  totalMalware?: number;
  transactionId?: number;
  planName?: string;
  amount?: number;
  durationDays?: number;
  paymentMethod?: string;
  title?: string;
  body?: string;
}

@Injectable()
export class NotificationWorker implements OnModuleInit {
  private readonly logger = new Logger(NotificationWorker.name);

  constructor(
    private readonly rabbitMQService: RabbitMQService,
    private readonly notificationService: NotificationService,
  ) {}

  onModuleInit() {
    this.rabbitMQService.consume(QUEUES.NOTIFICATION_JOBS, this.processNotificationJob.bind(this));
  }

  async processNotificationJob(payload: NotificationJobPayload): Promise<void> {
    this.logger.log(`[NotificationWorker] Processing notification job type: ${payload.type}`);

    try {
      if (payload.type === 'SCAN_RESULT' && payload.userId && payload.summaryId) {
        await this.notificationService.sendScanResultNotification(
          payload.userId,
          payload.summaryId,
          payload.totalScanned || 0,
          payload.totalMalware || 0,
          payload.email,
        );
      } else if (payload.type === 'PAYMENT_RECEIPT' && payload.email && payload.transactionId) {
        await this.notificationService.sendPaymentReceiptNotification({
          email: payload.email,
          transactionId: payload.transactionId,
          planName: payload.planName || 'Premium Plan',
          amount: payload.amount || 0,
          durationDays: payload.durationDays || 30,
          paymentMethod: payload.paymentMethod || 'qris',
        });
      } else if (payload.type === 'CUSTOM_PUSH' && payload.title && payload.body) {
        await this.notificationService.sendPushNotification({
          userId: payload.userId,
          title: payload.title,
          body: payload.body,
        });
      }
    } catch (err: any) {
      this.logger.error(`[NotificationWorker] Error dispatching notification: ${err.message}`);
    }
  }
}
