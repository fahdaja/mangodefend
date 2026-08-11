import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { summary_scans, scan_details } from '../api/scans/entity/scan.entity';
import { dataset_inventories } from '../api/dataset/entity/dataset.entity';
import { User } from '../api/users/entity/user.entity';
import { Plans, Subscriptions } from '../api/subscriptions/entity/subscription.entity';
import { ScanWorker } from './scan.worker';
import { SampleWorker } from './sample.worker';
import { PaymentWorker } from './payment.worker';
import { NotificationWorker } from './notification.worker';
import { NotificationModule } from '../api/notifications/notification.module';
import { SubscriptionModule } from '../api/subscriptions/subscription.module';
import { SupabaseModule } from '../common/supabase/supabase.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([summary_scans, scan_details, dataset_inventories, User, Plans, Subscriptions]),
    NotificationModule,
    SubscriptionModule,
    SupabaseModule,
  ],
  providers: [ScanWorker, SampleWorker, PaymentWorker, NotificationWorker],
})
export class WorkersModule {}
