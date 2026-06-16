import { Injectable, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import { scan_details, summary_scans } from '../entity/scan.entity';
import { dataset_inventories } from '../../dataset/entity/dataset.entity';
import { DatasetSource } from '../../dataset/enum/source.enum';
import { SupabaseService } from '../../../common/supabase/supabase.service';
import { ScanStatus, ScanType } from '../enum/scan.enum';
import { CreateScanDto } from '../dto/create-scan.dto';
import { label } from 'src/api/dataset/enum/label.enum';
import { Plans, Subscriptions } from '../../subscriptions/entity/subscription.entity';
import { PlanType } from '../../subscriptions/enum/plan.enum';

@Injectable()
export class ScanService {
  constructor(
    @InjectRepository(scan_details)
    private readonly scanDetailsRepo: Repository<scan_details>,
    @InjectRepository(summary_scans)
    private readonly summaryScansRepo: Repository<summary_scans>,
    @InjectRepository(dataset_inventories)
    private readonly datasetInventoryRepo: Repository<dataset_inventories>,
    @InjectRepository(Subscriptions)
    private readonly subscriptionRepository: Repository<Subscriptions>,
    @InjectRepository(Plans)
    private readonly planRepository: Repository<Plans>,
    private readonly supabaseService: SupabaseService,
  ) {}

  // validasi total file scan dan malware
  private resolveScanTotals(
    dto: CreateScanDto,
    actualFileCount: number,
    actualMalwareCount: number,
  ): { totalFilesScanned: number; totalMalwareDetected: number } {
    if (dto.scanType === ScanType.UPLOAD_FILE) {
      return this.validateUploadFileScan(
        dto,
        actualFileCount,
        actualMalwareCount,
      );
    }

    return this.validateFullScan(dto, actualFileCount, actualMalwareCount);
  }

  // Validation khusus untuk single file upload
  private validateUploadFileScan(
    dto: CreateScanDto,
    actualFileCount: number,
    actualMalwareCount: number,
  ) {
    if (actualFileCount !== 1) {
      throw new BadRequestException('File yang diupload harus tepat 1.');
    }

    if (dto.totalFiles !== 1) {
      throw new BadRequestException(
        `File yang diupload (1) tidak sesuai dengan total files yang dilaporkan (${dto.totalFiles}).`,
      );
    }

    if (dto.totalMalware !== undefined && dto.totalMalware !== 1) {
      throw new BadRequestException(
        `Total malware tidak boleh lebih dari 1 atau kurang dari 1 yang dilaporkan (${dto.totalMalware}).`,
      );
    }

    return {
      totalFilesScanned: actualFileCount,
      totalMalwareDetected: actualMalwareCount,
    };
  }

  // Validation khusus untuk full scan dari desktop aplikasi
  private validateFullScan(
    dto: CreateScanDto,
    actualFileCount: number,
    actualMalwareCount: number,
  ) {
    const reportedMalware = dto.totalMalware ?? 0;
    const totalFiles = dto.totalFiles;

    if (reportedMalware > totalFiles) {
      throw new BadRequestException(
        `Total malware (${reportedMalware}) tidak boleh lebih besar dari total files (${totalFiles}).`,
      );
    }

    if (totalFiles > actualFileCount) {
      throw new BadRequestException(
        `Total files (${totalFiles}) tidak boleh lebih besar dari file yang diupload (${actualFileCount}).`,
      );
    }

    if (totalFiles !== actualFileCount) {
      throw new BadRequestException(
        `Total files (${totalFiles}) tidak sama dengan jumlah file yang diupload (${actualFileCount}).`,
      );
    }
    // Validasi sinkronisasi file malware fisik vs laporan
    if (
      actualMalwareCount > 0 &&
      dto.totalMalware !== undefined &&
      actualFileCount !== reportedMalware
    ) {
      throw new BadRequestException(
        `File malware yang diupload (${actualFileCount}) tidak sesuai dengan totalMalware yang dilaporkan (${reportedMalware}).`,
      );
    }

    return {
      totalFilesScanned: totalFiles,
      totalMalwareDetected: actualMalwareCount,
    };
  }

  // proses membuat history scan dan upload images ke supabase
  async createScanWithUpload(files: Express.Multer.File[], dto: CreateScanDto) {
    // 0. Cek limits berdasarkan active subscription & scan type
    const activeSub = await this.subscriptionRepository.findOne({
      where: { user_id: dto.userId, is_active: true },
      relations: ['plan'],
      order: { end_date: 'DESC' },
    });

    let plan: Plans | null | undefined = activeSub?.plan;
    if (!plan) {
      plan = await this.planRepository.findOne({
        where: { plan_name: PlanType.FREE },
      });
    }

    const planName = plan?.plan_name || PlanType.FREE;
    let limit = 0;
    if (dto.scanType === ScanType.UPLOAD_FILE) {
      limit = plan?.upload_file_limit ?? 5;
    } else if (dto.scanType === ScanType.FULL_SCAN) {
      limit = plan?.full_scan_limit ?? 0;
    }

    if (limit === 0) {
      throw new ForbiddenException(
        `Tipe scan "${dto.scanType}" tidak diizinkan untuk paket "${planName}". Silahkan upgrade paket Anda.`,
      );
    }

    if (limit !== -1) {
      const startOfToday = new Date();
      startOfToday.setHours(0, 0, 0, 0);

      const todayScansCount = await this.summaryScansRepo.createQueryBuilder('scan')
        .where('scan.user_id = :userId', { userId: dto.userId })
        .andWhere('scan.scan_type = :scanType', { scanType: dto.scanType })
        .andWhere('scan.created_at >= :startOfToday', { startOfToday })
        .getCount();

      if (todayScansCount >= limit) {
        throw new ForbiddenException(
          `Batas scan harian untuk tipe "${dto.scanType}" (${limit} kali) telah tercapai pada paket "${planName}". Silahkan upgrade paket Anda untuk batas yang lebih tinggi.`,
        );
      }
    }

    const isMalware = dto.isMalware ?? true;
    const folderName = isMalware ? 'malware' : 'benign';
    const actualFileCount = files.length;
    const actualMalwareCount = isMalware ? actualFileCount : 0;

    const { totalFilesScanned } = this.resolveScanTotals(
      dto,
      actualFileCount,
      actualMalwareCount,
    );

    // 1. Proses setiap file: hitung hash → cek library → upload jika baru
    const savedDetails: scan_details[] = [];
    const libraryMatches: string[] = [];
    const newUploads: string[] = [];
    const fileResults: {
      file: Express.Multer.File;
      fileHash: string;
      fileIsMalware: boolean;
      matchedInLibrary: boolean;
    }[] = [];

    for (const file of files) {
      const fileHash = crypto
        .createHash('sha256')
        .update(file.buffer)
        .digest('hex');

      // Cek apakah hash sudah ada di dataset_inventories (library)
      const isExistInLibrary = await this.datasetInventoryRepo.findOne({
        where: { file_hash: fileHash },
      });

      // Tentukan status malware per file
      let fileIsMalware = isMalware;

      if (isExistInLibrary) {
        // Hash sudah dikenal di library → gunakan label yang ada, skip upload ke storage
        fileIsMalware = isExistInLibrary.label === label.MALWARE;
        libraryMatches.push(file.originalname);
      } else {
        // Hash baru → upload sample ke storage & simpan ke library (malware atau benign)
        await this.supabaseService.uploadScanImage(file, folderName, fileHash);
        await this.datasetInventoryRepo.save(
          this.datasetInventoryRepo.create({
            file_hash: fileHash,
            label: isMalware ? label.MALWARE : label.BENIGN,
            source: DatasetSource.SCAN,
          }),
        );
        newUploads.push(file.originalname);
      }

      fileResults.push({
        file,
        fileHash,
        fileIsMalware,
        matchedInLibrary: !!isExistInLibrary,
      });
    }

    // 2. Hitung total malware aktual setelah library check
    const actualMalwareDetected = fileResults.filter(
      (r) => r.fileIsMalware,
    ).length;

    // 3. Simpan summary ke database (dengan total malware yang akurat)
    const savedSummary = await this.summaryScansRepo.save(
      this.summaryScansRepo.create({
        user_id: dto.userId,
        scan_type: dto.scanType,
        status: ScanStatus.COMPLETED,
        total_files_scanned: totalFilesScanned,
        total_malware_detected: actualMalwareDetected,
      }),
    );

    // 4. Simpan scan_details per file
    for (const result of fileResults) {
      const detail = await this.scanDetailsRepo.save(
        this.scanDetailsRepo.create({
          summary_id: savedSummary.id,
          file_name: result.file.originalname,
          file_hash: result.fileHash,
          is_malware: result.fileIsMalware,
          matched_in_library: result.matchedInLibrary,
        }),
      );

      savedDetails.push(detail);
    }

    return {
      summary: savedSummary,
      details: savedDetails,
      library_info: {
        matched_from_library: libraryMatches.length,
        new_uploads: newUploads.length,
        matched_files: libraryMatches,
        uploaded_files: newUploads,
      },
    };
  }

  // Ambil 1 sesi scan beserta semua detailnya (1 query JOIN)
  async getScanResult(id: number) {
    const result = await this.summaryScansRepo.findOne({
      where: { id },
      relations: ['details'],
    });

    if (!result) throw new BadRequestException('Summary not found');

    return result;
  }

  // Ambil semua riwayat scan milik 1 user, beserta detailnya
  async getMyScanHistory(userId: number) {
    return this.summaryScansRepo.find({
      where: { user_id: userId },
      relations: ['details'],
      order: { created_at: 'DESC' },
    });
  }
}
