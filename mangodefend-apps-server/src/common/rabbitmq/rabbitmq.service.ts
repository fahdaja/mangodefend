import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as amqp from 'amqplib';

export const QUEUES = {
  SCAN_JOBS: 'scan_jobs',
  SAMPLE_JOBS: 'sample_jobs',
  PAYMENT_EVENTS: 'payment_events',
  NOTIFICATION_JOBS: 'notification_jobs',
} as const;

export type QueueName = typeof QUEUES[keyof typeof QUEUES];

@Injectable()
export class RabbitMQService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RabbitMQService.name);
  private connection: any = null;
  private channel: any = null;
  private isConnected = false;

  constructor(private readonly configService: ConfigService) {}

  async onModuleInit() {
    await this.connect();
  }

  async onModuleDestroy() {
    await this.close();
  }

  private async connect() {
    const url = this.configService.get<string>('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672');

    try {
      this.connection = (await amqp.connect(url)) as any;
      this.channel = (await this.connection.createChannel()) as any;
      this.isConnected = true;
      this.logger.log('Successfully connected to RabbitMQ Message Broker');

      // Assert standard queues
      for (const q of Object.values(QUEUES)) {
        await this.channel.assertQueue(q, { durable: true });
      }

      this.connection.on('error', (err: any) => {
        this.logger.warn(`RabbitMQ connection error: ${err.message}`);
        this.isConnected = false;
      });

      this.connection.on('close', () => {
        this.logger.warn('RabbitMQ connection closed');
        this.isConnected = false;
      });
    } catch (err: any) {
      this.logger.warn(`Failed to connect to RabbitMQ broker: ${err.message}. Running in sync fallback mode.`);
      this.isConnected = false;
    }
  }

  private async close() {
    try {
      if (this.channel) await this.channel.close();
      if (this.connection) await this.connection.close();
    } catch (err: any) {
      this.logger.warn(`Error closing RabbitMQ connections: ${err.message}`);
    }
  }

  async publish(queue: QueueName, data: any): Promise<boolean> {
    if (!this.channel || !this.isConnected) {
      this.logger.warn(`RabbitMQ channel unavailable. Skipping publish to queue ${queue}`);
      return false;
    }

    try {
      await this.channel.assertQueue(queue, { durable: true });
      const buffer = Buffer.from(JSON.stringify(data));
      this.channel.sendToQueue(queue, buffer, { persistent: true });
      this.logger.log(`Published message to queue: ${queue}`);
      return true;
    } catch (err: any) {
      this.logger.error(`Failed to publish message to ${queue}: ${err.message}`);
      return false;
    }
  }

  async consume(queue: QueueName, onMessage: (data: any) => Promise<void>): Promise<void> {
    if (!this.channel || !this.isConnected) {
      this.logger.warn(`RabbitMQ channel unavailable. Cannot register consumer for ${queue}`);
      return;
    }

    try {
      await this.channel.assertQueue(queue, { durable: true });
      await this.channel.prefetch(1);

      this.channel.consume(queue, async (msg) => {
        if (!msg) return;

        try {
          const content = JSON.parse(msg.content.toString());
          await onMessage(content);
          this.channel?.ack(msg);
        } catch (err: any) {
          this.logger.error(`Error processing queue message from ${queue}: ${err.message}`);
          // Nack and don't requue if failed
          this.channel?.nack(msg, false, false);
        }
      });

      this.logger.log(`Registered consumer for queue: ${queue}`);
    } catch (err: any) {
      this.logger.error(`Failed to consume from queue ${queue}: ${err.message}`);
    }
  }
}
