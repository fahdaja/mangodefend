import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MlModel } from './entity/ml.entity';
import { Plans, Subscriptions } from '../subscriptions/entity/subscription.entity';
import { MlController } from './controllers/ml.controller';
import { MlService } from './services/ml.service';
import { AuthModule } from '../auth/auth.module';

@Module({
    imports: [TypeOrmModule.forFeature([MlModel, Plans, Subscriptions]), AuthModule],
    controllers: [MlController],
    providers: [MlService],
    exports: [MlService]
})
export class MlModule {}
