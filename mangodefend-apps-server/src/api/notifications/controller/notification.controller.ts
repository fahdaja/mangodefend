import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { NotificationService, SendPushDto } from '../service/notification.service';
import { AuthGuard } from '../../auth/guard/auth.guard';
import { RolesGuard } from '../../auth/guard/roles.guard';
import { Roles } from '../../../common/decorator/roles.decorator';
import { Role } from '../../users/enum/roles.enum';

@Controller('notifications')
@UseGuards(AuthGuard, RolesGuard)
export class NotificationController {
  constructor(private readonly notificationService: NotificationService) {}

  @Post('push')
  @Roles(Role.ADMIN)
  async sendPushNotification(@Body() dto: SendPushDto) {
    const success = await this.notificationService.sendPushNotification(dto);
    return {
      status: success ? 'success' : 'failed',
      message: success ? 'Push notification dispatched' : 'Failed to dispatch push notification',
    };
  }
}
