import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../../auth/guards/auth.guard';
import { RoleGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../../common/decorator/roles.decorator';
import { Role } from '../../users/enum/roles.enum';
import { DatasetService } from '../service/dataset.service';

@UseGuards(AuthGuard, RoleGuard)
@Roles(Role.ADMIN)
@Controller('dataset')
export class DatasetController {
  constructor(private readonly datasetService: DatasetService) {}

  @Get('malware')
  async getDataMalware() {
    return this.datasetService.getDataMalware();
  }

  @Get('benign')
  async getDataBenign() {
    return this.datasetService.getDataBenign();
  }

  @Get('stats')
  async getStats(@Query('range') range?: string) {
    return this.datasetService.getStats(range);
  }

  @Get('recent')
  async getRecent(
    @Query('label') label?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.datasetService.getRecent(
      label,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 20,
    );
  }

  @Get('unimported-malware')
  async getUnimportedMalware(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.datasetService.getUnimportedMalware(
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 20,
    );
  }

  @Post('import')
  async importToInventory(
    @Body('file_hash') fileHash: string,
    @Body('label') labelVal?: any,
  ) {
    return this.datasetService.importToInventory(fileHash, labelVal);
  }
}
