import {
  Controller,
  Post,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
  Body,
  ValidationPipe,
  UseGuards,
  Get,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ScanService } from '../service/scan.service';
import { CreateScanDto } from '../dto/create-scan.dto';
import { AuthGuard } from '../../auth/guards/auth.guard';
import { RoleGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../../common/decorator/roles.decorator';
import { Role } from '../../users/enum/roles.enum';

@UseGuards(AuthGuard, RoleGuard)
@Roles(Role.CLIENT)
@Controller('scans')
export class ScanController {
  constructor(private readonly scanService: ScanService) {}

  @Post()
  @UseInterceptors(FilesInterceptor('files', 50)) // max 50 file sekaligus
  async createScan(
    @UploadedFiles() files: Express.Multer.File[],
    @Body(new ValidationPipe({ transform: true })) dto: CreateScanDto,
  ) {
    if (!files || files.length === 0) {
      return { message: '1 file is required' };
    }

    const result = await this.scanService.createScanWithUpload(files, dto);

    const { matched_from_library, new_uploads } = result.library_info;
    let message: string;

    if (matched_from_library > 0 && new_uploads === 0) {
      message = `Scan selesai. ${matched_from_library} file sudah dikenal di library, tidak ada upload baru.`;
    } else if (matched_from_library > 0 && new_uploads > 0) {
      message = `Scan selesai. ${matched_from_library} file ditemukan di library, ${new_uploads} file baru diupload.`;
    } else {
      message = `Scan selesai. ${new_uploads} file baru berhasil diupload.`;
    }

    return {
      message,
      data: result,
    };
  }

  @Get('detail/:id')
  async getScanResult(@Param('id', ParseIntPipe) id: number) {
    const result = await this.scanService.getScanResult(id);

    return {
      message: 'Scan result fetched successfully',
      data: result,
    };
  }

  @Get('history/:userId')
  async getMyScanHistory(@Param('userId', ParseIntPipe) userId: number) {
    const result = await this.scanService.getMyScanHistory(userId);

    return {
      message: 'Scan history fetched successfully',
      data: result,
    };
  }
}
