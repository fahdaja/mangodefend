import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { dataset_inventories } from '../entity/dataset.entity';
import { DatasetSource } from '../enum/source.enum';
import { label } from '../enum/label.enum';
import { SupabaseService } from '../../../common/supabase/supabase.service';

@Injectable()
export class DatasetSeederService {
  private readonly logger = new Logger(DatasetSeederService.name);

  constructor(
    @InjectRepository(dataset_inventories)
    private readonly datasetRepo: Repository<dataset_inventories>,
    private readonly supabaseService: SupabaseService,
  ) {}

  /**
   * Seed dataset dari folder lokal ke database dan Supabase storage.
   * Struktur folder yang diharapkan:
   *   folderPath/
   *     ├── malware/    ← file-file malware
   *     └── benign/     ← file-file benign
   *
   * @param folderPath - Path absolut ke folder yang berisi subfolder malware/ dan benign/
   */
  async seedFromFolder(folderPath: string) {
    this.logger.log(`Memulai seeding dari folder: ${folderPath}`);

    const malwareDir = path.join(folderPath, 'malware');
    const benignDir = path.join(folderPath, 'benign');

    let totalProcessed = 0;
    let totalSkipped = 0;
    let totalUploaded = 0;

    // Seed malware files
    if (fs.existsSync(malwareDir)) {
      const result = await this.seedDirectory(malwareDir, label.MALWARE);
      totalProcessed += result.processed;
      totalSkipped += result.skipped;
      totalUploaded += result.uploaded;
    } else {
      this.logger.warn(`Folder malware tidak ditemukan: ${malwareDir}`);
    }

    // Seed benign files
    if (fs.existsSync(benignDir)) {
      const result = await this.seedDirectory(benignDir, label.BENIGN);
      totalProcessed += result.processed;
      totalSkipped += result.skipped;
      totalUploaded += result.uploaded;
    } else {
      this.logger.warn(`Folder benign tidak ditemukan: ${benignDir}`);
    }

    const summary = {
      total_processed: totalProcessed,
      total_uploaded: totalUploaded,
      total_skipped: totalSkipped,
    };

    this.logger.log(`Seeding selesai: ${JSON.stringify(summary)}`);
    return summary;
  }

  /**
   * Proses semua file dalam satu direktori.
   */
  private async seedDirectory(
    dirPath: string,
    fileLabel: label,
  ): Promise<{ processed: number; skipped: number; uploaded: number }> {
    const files = fs.readdirSync(dirPath).filter((f) => {
      const fullPath = path.join(dirPath, f);
      return fs.statSync(fullPath).isFile();
    });

    this.logger.log(
      `Ditemukan ${files.length} file di ${dirPath} (label: ${fileLabel})`,
    );

    let skipped = 0;
    let uploaded = 0;

    for (const fileName of files) {
      const filePath = path.join(dirPath, fileName);
      const fileBuffer = fs.readFileSync(filePath);

      // Hitung SHA-256 hash
      const fileHash = crypto
        .createHash('sha256')
        .update(fileBuffer)
        .digest('hex');

      // Cek duplikat di database
      const existing = await this.datasetRepo.findOne({
        where: { file_hash: fileHash },
      });

      if (existing) {
        this.logger.verbose(`SKIP (duplikat): ${fileName} [${fileHash.slice(0, 12)}...]`);
        skipped++;
        continue;
      }

      // Upload ke Supabase storage
      const folderName = fileLabel === label.MALWARE ? 'malware' : 'benign';
      const extension = path.extname(fileName) || '.bin';

      const multerFile: Express.Multer.File = {
        fieldname: 'files',
        originalname: fileName,
        encoding: '7bit',
        mimetype: 'application/octet-stream',
        buffer: fileBuffer,
        size: fileBuffer.length,
        stream: null as any,
        destination: '',
        filename: fileName,
        path: filePath,
      };

      try {
        await this.supabaseService.uploadScanImage(
          multerFile,
          folderName,
          fileHash,
        );
      } catch (error) {
        this.logger.error(`Gagal upload ${fileName}: ${error.message}`);
        continue;
      }

      // Simpan ke database
      await this.datasetRepo.save(
        this.datasetRepo.create({
          file_hash: fileHash,
          label: fileLabel,
          source: DatasetSource.SEEDER,
        }),
      );

      this.logger.log(`UPLOADED: ${fileName} → ${folderName}/ [${fileHash.slice(0, 12)}...]`);
      uploaded++;
    }

    return { processed: files.length, skipped, uploaded };
  }
}
