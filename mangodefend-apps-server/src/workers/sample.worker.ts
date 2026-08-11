import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { RabbitMQService, QUEUES } from '../common/rabbitmq/rabbitmq.service';
import { SupabaseService } from '../common/supabase/supabase.service';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { dataset_inventories } from '../api/dataset/entity/dataset.entity';
import { DatasetSource } from '../api/dataset/enum/source.enum';
import { label } from '../api/dataset/enum/label.enum';

export interface SampleJobPayload {
  folderName: string;
  fileHash: string;
  isMalware: boolean;
  fileBufferBase64: string;
  originalname: string;
  mimetype: string;
}

@Injectable()
export class SampleWorker implements OnModuleInit {
  private readonly logger = new Logger(SampleWorker.name);

  constructor(
    private readonly rabbitMQService: RabbitMQService,
    private readonly supabaseService: SupabaseService,
    @InjectRepository(dataset_inventories)
    private readonly datasetInventoryRepo: Repository<dataset_inventories>,
  ) {}

  onModuleInit() {
    this.rabbitMQService.consume(QUEUES.SAMPLE_JOBS, this.processSampleJob.bind(this));
  }

  async processSampleJob(payload: SampleJobPayload): Promise<void> {
    this.logger.log(`[SampleWorker] Uploading sample ${payload.originalname} (${payload.fileHash}) to Supabase Storage`);

    try {
      const buffer = Buffer.from(payload.fileBufferBase64, 'base64');
      const multerFile: Express.Multer.File = {
        fieldname: 'file',
        originalname: payload.originalname,
        encoding: '7bit',
        mimetype: payload.mimetype || 'application/octet-stream',
        buffer,
        size: buffer.length,
        stream: null as any,
        destination: '',
        filename: payload.originalname,
        path: '',
      };

      const publicUrl = await this.supabaseService.uploadScanImage(
        multerFile,
        payload.folderName,
        payload.fileHash,
      );

      // Record to dataset inventory if not existing
      const existing = await this.datasetInventoryRepo.findOne({
        where: { file_hash: payload.fileHash },
      });

      if (!existing) {
        await this.datasetInventoryRepo.save(
          this.datasetInventoryRepo.create({
            file_hash: payload.fileHash,
            label: payload.isMalware ? label.MALWARE : label.BENIGN,
            source: DatasetSource.SCAN,
          }),
        );
      }

      this.logger.log(`[SampleWorker] Sample upload complete. Public URL: ${publicUrl}`);
    } catch (err: any) {
      this.logger.error(`[SampleWorker] Failed to process sample upload: ${err.message}`);
    }
  }
}
