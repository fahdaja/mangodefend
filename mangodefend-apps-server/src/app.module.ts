import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { UserModule } from './api/users/user.module';
import { AuthModule } from './api/auth/auth.module'; 
import { SubscriptionModule } from './api/subscriptions/subscription.module';
import { TransactionModule } from './api/transactions/transaction.module';
import { MlModule } from './api/ml/ml.module';
import { HashModule } from './common/hash/hash.module';
import { FirebaseModule } from './common/firebase/firebase.module';
import { ScanModule } from './api/scans/scan.module';
import { DatasetModule } from './api/dataset/dataset.module';
import { RedisModule } from './common/redis/redis.module';
import { RabbitMQModule } from './common/rabbitmq/rabbitmq.module';
import { MailModule } from './common/mail/mail.module';
import { DeviceModule } from './api/devices/device.module';
import { NotificationModule } from './api/notifications/notification.module';
import { WorkersModule } from './workers/workers.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true, 
      envFilePath: '.env',
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        url: configService.get<string>('DATABASE_URL'),
        autoLoadEntities: true,
        synchronize: true,
      }),
    }),
    HashModule,
    FirebaseModule,
    RedisModule,
    RabbitMQModule,
    MailModule,
    UserModule,
    AuthModule,
    SubscriptionModule,
    TransactionModule,
    MlModule,
    ScanModule,
    DatasetModule,
    DeviceModule,
    NotificationModule,
    WorkersModule,
  ],
})
export class AppModule {}

