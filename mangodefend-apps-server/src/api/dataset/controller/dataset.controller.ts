import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../../auth/guard/auth.guard';
import { RoleGuard } from '../../auth/guard/roles.guard';

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
}
