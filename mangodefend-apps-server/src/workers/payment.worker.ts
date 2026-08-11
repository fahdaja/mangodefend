import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { RabbitMQService, QUEUES } from '../common/rabbitmq/rabbitmq.service';
import { SubscriptionService } from '../api/subscriptions/service/subscription.service';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../api/users/entity/user.entity';
import { Plans } from '../api/subscriptions/entity/subscription.entity';

export interface PaymentEventPayload {
  transactionId: number;
  userId: number;
  planId: number;
  amount: number;
  paymentMethod: string;
}

@Injectable()
export class PaymentWorker implements OnModuleInit {
  private readonly logger = new Logger(PaymentWorker.name);

  constructor(
    private readonly rabbitMQService: RabbitMQService,
    private readonly subscriptionService: SubscriptionService,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Plans)
    private readonly planRepository: Repository<Plans>,
  ) {}

  onModuleInit() {
    this.rabbitMQService.consume(QUEUES.PAYMENT_EVENTS, this.processPaymentEvent.bind(this));
  }

  async processPaymentEvent(payload: PaymentEventPayload): Promise<void> {
    this.logger.log(`[PaymentWorker] Processing payment event for Tx #${payload.transactionId}, User #${payload.userId}`);

    try {
      // Activate premium subscription
      await this.subscriptionService.createSubscription({
        user_id: payload.userId,
        plan_id: payload.planId,
      });

      const user = await this.userRepository.findOne({ where: { id: payload.userId } });
      const plan = await this.planRepository.findOne({ where: { id: payload.planId } });

      if (user && plan) {
        // Enqueue receipt notification
        await this.rabbitMQService.publish(QUEUES.NOTIFICATION_JOBS, {
          type: 'PAYMENT_RECEIPT',
          email: user.email,
          transactionId: payload.transactionId,
          planName: plan.plan_name,
          amount: payload.amount,
          durationDays: plan.durationDays,
          paymentMethod: payload.paymentMethod,
        });
      }

      this.logger.log(`[PaymentWorker] Premium subscription activated successfully for User #${payload.userId}`);
    } catch (err: any) {
      this.logger.error(`[PaymentWorker] Failed to process payment event: ${err.message}`);
    }
  }
}
