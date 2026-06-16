import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  ParseIntPipe,
  Patch,
  UseGuards,
  Delete,
  Query,
  Request,
} from '@nestjs/common';
import { MlService } from '../services/ml.service';
import { CreateMlModelDto } from '../dto/create-ml.dto';
import { AuthGuard } from '../../auth/guards/auth.guard';
import { RoleGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../../common/decorator/roles.decorator';
import { Role } from '../../users/enum/roles.enum';

@Controller('models')
export class MlController {
  constructor(private readonly mlService: MlService) {}

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Get('system-logs')
  async getSystemLogs(@Query('lines') lines?: string) {
    const limitLines = parseInt(lines || '100', 10) || 100;
    const fs = require('fs');
    const path = require('path');
    const logFilePath = path.join(process.cwd(), 'nestjs_server.log');
    try {
      if (!fs.existsSync(logFilePath)) {
        return { logs: [`Log file not found at ${logFilePath}`] };
      }
      const fileContent = fs.readFileSync(logFilePath, 'utf-8');
      const allLines = fileContent.split('\n');
      if (allLines[allLines.length - 1] === '') {
        allLines.pop();
      }
      const lastLines = allLines.slice(-limitLines);
      return { logs: lastLines };
    } catch (e) {
      return { logs: [`Error reading log file: ${e.message}`] };
    }
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Post()
  async createModel(@Body() createMlModelDto: CreateMlModelDto) {
    return this.mlService.createModel(createMlModelDto);
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Get()
  async getAllModels() {
    return this.mlService.findAllModels();
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Patch(':id/status')
  async toggleModelStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body('is_active') is_active: boolean,
  ) {
    return this.mlService.toggleModelStatus(id, is_active);
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Delete(':id')
  async deleteModel(@Param('id', ParseIntPipe) id: number) {
    return this.mlService.deleteModel(id);
  }

  @UseGuards(AuthGuard)
  @Get('active-model')
  async getActiveModel(@Request() req) {
    const userId = req.user.id;
    const model = await this.mlService.findActiveModelForUser(userId);
    return {
      status: 'success',
      data: model,
    };
  }
}
