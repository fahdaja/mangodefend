import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Device } from '../users/entity/user.entity';
import { Subscriptions } from '../subscriptions/entity/subscription.entity';
import { DeviceService } from './service/device.service';
import { DeviceController } from './controller/device.controller';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [TypeOrmModule.forFeature([Device, Subscriptions]), AuthModule],
  controllers: [DeviceController],
  providers: [DeviceService],
  exports: [DeviceService],
})
export class DeviceModule {}
