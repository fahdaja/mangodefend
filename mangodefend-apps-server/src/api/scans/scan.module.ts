import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScanService } from './service/scan.service';
import { ScanController } from './controller/scan.controller';
import { scan_details, summary_scans } from './entity/scan.entity';
import { dataset_inventories } from '../dataset/entity/dataset.entity';
import { Plans, Subscriptions } from '../subscriptions/entity/subscription.entity';
import { SupabaseModule } from '../../common/supabase/supabase.module';
import { AuthModule } from '../auth/auth.module';
import { DatasetModule } from '../dataset/dataset.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([summary_scans, scan_details, dataset_inventories, Subscriptions, Plans]),
    DatasetModule,
    SupabaseModule,
    AuthModule,
  ],
  controllers: [ScanController],
  providers: [ScanService],
  exports: [ScanService],
})
export class ScanModule {}

