import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  ParseIntPipe,
  UseGuards,
  Request,
  Patch,
  Delete,
} from '@nestjs/common';
import { SubscriptionService } from '../service/subscription.service';
import { CreatePlanDto } from '../dto/create-plan.dto';
import { AuthGuard } from '../../auth/guards/auth.guard';
import { RoleGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../../common/decorator/roles.decorator';
import { Role } from '../../users/enum/roles.enum';

@Controller('subscriptions')
export class SubscriptionController {
  constructor(private readonly subscriptionService: SubscriptionService) {}

  @Get('active/:userId')
  async getActiveSubscriptions(@Param('userId', ParseIntPipe) userId: number) {
    return this.subscriptionService.findAllActiveSubscription(userId);
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Get('all')
  async getAllSubscriptions() {
    return this.subscriptionService.findAllSubscriptionsWithUser();
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Post('plan')
  async createPlan(@Body() createPlanDto: CreatePlanDto, @Request() req) {
    createPlanDto.user_id = req.user.id;
    return this.subscriptionService.createPlan(createPlanDto);
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Patch('plan/:id')
  async updatePlan(
    @Param('id', ParseIntPipe) id: number,
    @Body() data: Partial<CreatePlanDto>,
  ) {
    return this.subscriptionService.updatePlan(id, data);
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Delete('plan/:id')
  async deletePlan(@Param('id', ParseIntPipe) id: number) {
    return this.subscriptionService.deletePlan(id);
  }

  @Get('plan')
  async getAllPlans() {
    return this.subscriptionService.findAllPlans();
  }
}
