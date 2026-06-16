import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { DatasetService } from './service/dataset.service';
import { DatasetSeederService } from './service/dataset-seeder.service';
import { DatasetController } from './controller/dataset.controller';
import { dataset_inventories } from './entity/dataset.entity';
import { scan_details } from '../scans/entity/scan.entity';
import { AuthModule } from '../auth/auth.module';
import { SupabaseModule } from '../../common/supabase/supabase.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([dataset_inventories, scan_details]),
    AuthModule,
    SupabaseModule,
  ],
  controllers: [DatasetController],
  providers: [DatasetService, DatasetSeederService],
  exports: [TypeOrmModule, DatasetService, DatasetSeederService],
})
export class DatasetModule {}
