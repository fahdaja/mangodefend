import { Injectable, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import type { Repository } from 'typeorm';
import { Device } from '../../users/entity/user.entity';
import { Subscriptions, SubscriptionStatus } from '../../subscriptions/entity/subscription.entity';
import { RegisterDeviceDto, DeactivateDeviceDto } from '../dto/device.dto';
import { RedisService } from '../../../common/redis/redis.service';

@Injectable()
export class DeviceService {
  constructor(
    @InjectRepository(Device)
    private readonly deviceRepository: Repository<Device>,
    @InjectRepository(Subscriptions)
    private readonly subscriptionRepository: Repository<Subscriptions>,
    private readonly redisService: RedisService,
  ) {}

  async registerDevice(userId: number, dto: RegisterDeviceDto): Promise<Device> {
    const existingDevice = await this.deviceRepository.findOne({
      where: { user_id: userId, hardware_id: dto.hardware_id },
    });

    const now = new Date();

    if (existingDevice) {
      existingDevice.hostname = dto.hostname;
      existingDevice.os_type = dto.os_type;
      existingDevice.app_type = dto.app_type;
      existingDevice.is_active = true;
      existingDevice.last_login = now;

      const saved = await this.deviceRepository.save(existingDevice);
      await this.updateDeviceCache(userId);
      return saved;
    }

    // Check device limit based on subscription plan
    const activeSub = await this.subscriptionRepository.findOne({
      where: { user_id: userId, is_active: true, status: SubscriptionStatus.ACTIVE },
      relations: ['plan'],
      order: { end_date: 'DESC' },
    });

    // Default max devices for Free plan: 2, Pro/Enterprise: plan specified limit or 5
    const deviceLimit = activeSub?.plan?.device_limit ?? 2;

    let activeCount = await this.redisService.getActiveDeviceCount(userId);
    if (activeCount === null) {
      activeCount = await this.deviceRepository.count({
        where: { user_id: userId, is_active: true },
      });
      await this.redisService.setActiveDeviceCount(userId, activeCount);
    }

    if (deviceLimit !== -1 && activeCount >= deviceLimit) {
      throw new ForbiddenException(
        `Batas maksimum perangkat (${deviceLimit}) untuk paket Anda telah tercapai. Harap nonaktifkan perangkat lain atau upgrade paket Anda.`,
      );
    }

    const newDevice = this.deviceRepository.create({
      user_id: userId,
      hardware_id: dto.hardware_id,
      hostname: dto.hostname,
      os_type: dto.os_type,
      app_type: dto.app_type,
      is_active: true,
      last_login: now,
      last_active: null,
    });

    const saved = await this.deviceRepository.save(newDevice);
    await this.updateDeviceCache(userId);
    return saved;
  }

  async getUserDevices(userId: number): Promise<Device[]> {
    return await this.deviceRepository.find({
      where: { user_id: userId },
      order: { last_login: 'DESC' },
    });
  }

  async deactivateDevice(userId: number, hardwareId: string): Promise<{ message: string }> {
    const device = await this.deviceRepository.findOne({
      where: { user_id: userId, hardware_id: hardwareId },
    });

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    device.is_active = false;
    device.last_active = new Date();
    await this.deviceRepository.save(device);

    await this.updateDeviceCache(userId);
    return { message: 'Perangkat berhasil dinonaktifkan' };
  }

  private async updateDeviceCache(userId: number): Promise<void> {
    const count = await this.deviceRepository.count({
      where: { user_id: userId, is_active: true },
    });
    await this.redisService.setActiveDeviceCount(userId, count);
  }
}
