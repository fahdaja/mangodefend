import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  HttpException,
  Get,
  UseGuards,
  Query,
  ParseIntPipe,
  Param,
} from '@nestjs/common';
import { UserService } from '../services/user.service';
import { CreateUserDto, UserResponseDto } from '../dto/user.dto';
import { AuthGuard } from 'src/api/auth/guards/auth.guard';
import { RoleGuard } from 'src/api/auth/guards/roles.guard';
import { Roles } from 'src/common/decorator/roles.decorator';
import { Role } from '../enum/roles.enum';

@Controller()
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('/register')
  @HttpCode(HttpStatus.CREATED)
  async register(
    @Body() createUserDto: CreateUserDto,
  ): Promise<{ message: string; data: UserResponseDto }> {
    try {
      const user = await this.userService.createUser(createUserDto);
      const response: UserResponseDto = {
        id: user.id,
        email: user.email,
        createdAt: user.createdAt,
      };
      return {
        message: 'User registered successfully',
        data: response,
      };
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      throw new HttpException(
        'Internal Server Error',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Get('/stats')
  async getStats() {
    return this.userService.getDashboardStats();
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Get('/users')
  async findAll(
    @Query('search') search?: string,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    // Service sekarang menerima parameter untuk performa tinggi
    return this.userService.findAll(search, page, limit);
  }

  @UseGuards(AuthGuard, RoleGuard)
  @Roles(Role.ADMIN)
  @Get('/:id/devices')
  async getUserDevices(@Param('id', ParseIntPipe) id: number) {
    const devices = await this.userService.findUserDevices(id);
    return { data: devices };
  }
}
