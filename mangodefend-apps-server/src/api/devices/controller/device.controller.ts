import { Controller, Post, Get, Body, UseGuards, Request } from '@nestjs/common';
import { DeviceService } from '../service/device.service';
import { RegisterDeviceDto, DeactivateDeviceDto } from '../dto/device.dto';
import { AuthGuard } from '../../auth/guard/auth.guard';

@Controller('devices')
@UseGuards(AuthGuard)
export class DeviceController {
  constructor(private readonly deviceService: DeviceService) {}

  @Post('register')
  async registerDevice(@Request() req: any, @Body() dto: RegisterDeviceDto) {
    const userId = req.user.id;
    const data = await this.deviceService.registerDevice(userId, dto);
    return {
      status: 'success',
      message: 'Perangkat berhasil terdaftar/diperbarui',
      data,
    };
  }

  @Get()
  async getUserDevices(@Request() req: any) {
    const userId = req.user.id;
    const data = await this.deviceService.getUserDevices(userId);
    return {
      status: 'success',
      data,
    };
  }

  @Post('deactivate')
  async deactivateDevice(@Request() req: any, @Body() dto: DeactivateDeviceDto) {
    const userId = req.user.id;
    const data = await this.deviceService.deactivateDevice(userId, dto.hardware_id);
    return {
      status: 'success',
      ...data,
    };
  }
}
