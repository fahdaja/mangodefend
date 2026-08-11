import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { RabbitMQService, QUEUES } from '../common/rabbitmq/rabbitmq.service';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { summary_scans, scan_details } from '../api/scans/entity/scan.entity';
import { ScanStatus } from '../api/scans/enum/scan.enum';
import { NotificationService } from '../api/notifications/service/notification.service';
import { RedisService } from '../common/redis/redis.service';

export interface ScanJobPayload {
  summaryId: number;
  userId: number;
  scanType: string;
  files: {
    originalname: string;
    fileHash: string;
    isMalware: boolean;
  }[];
}

@Injectable()
export class ScanWorker implements OnModuleInit {
  private readonly logger = new Logger(ScanWorker.name);

  constructor(
    private readonly rabbitMQService: RabbitMQService,
    private readonly notificationService: NotificationService,
    private readonly redisService: RedisService,
    @InjectRepository(summary_scans)
    private readonly summaryScansRepo: Repository<summary_scans>,
    @InjectRepository(scan_details)
    private readonly scanDetailsRepo: Repository<scan_details>,
  ) {}

  onModuleInit() {
    this.rabbitMQService.consume(QUEUES.SCAN_JOBS, this.processScanJob.bind(this));
  }

  async processScanJob(payload: ScanJobPayload): Promise<void> {
    this.logger.log(`[ScanWorker] Processing scan job for summaryId #${payload.summaryId}`);

    const summary = await this.summaryScansRepo.findOne({ where: { id: payload.summaryId } });
    if (!summary) {
      this.logger.error(`Summary #${payload.summaryId} not found`);
      return;
    }

    let actualMalwareCount = 0;

    for (const f of payload.files) {
      // Cache SHA fingerprint in Redis
      await this.redisService.setFingerprint(f.fileHash, f.isMalware);

      if (f.isMalware) actualMalwareCount++;
    }

    summary.status = ScanStatus.COMPLETED;
    summary.total_malware_detected = actualMalwareCount;
    await this.summaryScansRepo.save(summary);

    // Queue or directly trigger result notification
    await this.rabbitMQService.publish(QUEUES.NOTIFICATION_JOBS, {
      type: 'SCAN_RESULT',
      userId: payload.userId,
      summaryId: summary.id,
      totalScanned: summary.total_files_scanned,
      totalMalware: actualMalwareCount,
    });

    this.logger.log(`[ScanWorker] Completed scan job #${payload.summaryId}. Malware detected: ${actualMalwareCount}`);
  }
}
