import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { dataset_inventories } from '../entity/dataset.entity';
import { scan_details } from '../../scans/entity/scan.entity';
import { label } from '../enum/label.enum';
import { DatasetSource } from '../enum/source.enum';

@Injectable()
export class DatasetService {
  constructor(
    @InjectRepository(dataset_inventories)
    private readonly datasetInventoryRepository: Repository<dataset_inventories>,
    @InjectRepository(scan_details)
    private readonly scanDetailsRepository: Repository<scan_details>,
  ) {}

  async getDataMalware(): Promise<dataset_inventories[]> {
    return this.datasetInventoryRepository.find({
      where: { label: label.MALWARE },
    });
  }

  async getDataBenign(): Promise<dataset_inventories[]> {
    return this.datasetInventoryRepository.find({
      where: { label: label.BENIGN },
    });
  }

  /**
   * Get dataset statistics: counts by label, by source, and timeline data.
   */
  async getStats(range: string = '30d') {
    // Count by label
    const labelCounts = await this.datasetInventoryRepository
      .createQueryBuilder('d')
      .select('d.label', 'label')
      .addSelect('COUNT(d.id)', 'count')
      .groupBy('d.label')
      .getRawMany();

    // Count by source
    const sourceCounts = await this.datasetInventoryRepository
      .createQueryBuilder('d')
      .select('d.source', 'source')
      .addSelect('COUNT(d.id)', 'count')
      .groupBy('d.source')
      .getRawMany();

    // Count by label + source (for breakdown)
    const breakdownCounts = await this.datasetInventoryRepository
      .createQueryBuilder('d')
      .select('d.label', 'label')
      .addSelect('d.source', 'source')
      .addSelect('COUNT(d.id)', 'count')
      .groupBy('d.label')
      .addGroupBy('d.source')
      .getRawMany();

    // Timeline: query configuration based on range
    let selectExpr = "TO_CHAR(d.uploaded_at, 'YYYY-MM-DD')";
    let interval = "30 days";

    if (range === '7d') {
      selectExpr = "TO_CHAR(d.uploaded_at, 'YYYY-MM-DD')";
      interval = "7 days";
    } else if (range === '12m') {
      selectExpr = "TO_CHAR(d.uploaded_at, 'YYYY-MM')";
      interval = "12 months";
    }

    const timeline = await this.datasetInventoryRepository
      .createQueryBuilder('d')
      .select(selectExpr, 'date')
      .addSelect('d.label', 'label')
      .addSelect('COUNT(d.id)', 'count')
      .where(`d.uploaded_at >= NOW() - INTERVAL '${interval}'`)
      .groupBy(selectExpr)
      .addGroupBy('d.label')
      .orderBy(selectExpr, 'ASC')
      .getRawMany();

    const total = await this.datasetInventoryRepository.count();

    return {
      total,
      by_label: labelCounts.map((r) => ({ label: r.label, count: parseInt(r.count) })),
      by_source: sourceCounts.map((r) => ({ source: r.source, count: parseInt(r.count) })),
      breakdown: breakdownCounts.map((r) => ({
        label: r.label,
        source: r.source,
        count: parseInt(r.count),
      })),
      timeline: timeline.map((r) => ({
        date: r.date,
        label: r.label,
        count: parseInt(r.count),
      })),
    };
  }

  /**
   * Get recent dataset samples with pagination and optional label filter.
   */
  async getRecent(
    filterLabel?: string,
    page: number = 1,
    limit: number = 20,
  ) {
    const queryBuilder = this.datasetInventoryRepository
      .createQueryBuilder('d')
      .orderBy('d.uploaded_at', 'DESC');

    if (filterLabel && (filterLabel === 'malware' || filterLabel === 'benign')) {
      queryBuilder.where('d.label = :label', { label: filterLabel });
    }

    const total = await queryBuilder.getCount();

    const data = await queryBuilder
      .skip((page - 1) * limit)
      .take(limit)
      .getMany();

    return {
      data,
      meta: {
        total,
        page,
        limit,
        lastPage: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get detected malware from scan history that is not in dataset inventories.
   */
  async getUnimportedMalware(page: number = 1, limit: number = 20) {
    const queryBuilder = this.scanDetailsRepository
      .createQueryBuilder('sd')
      .innerJoinAndSelect('sd.summary', 'summary')
      .where('sd.is_malware = :isMalware', { isMalware: true })
      .andWhere(qb => {
        const subQuery = qb
          .subQuery()
          .select('di.file_hash')
          .from(dataset_inventories, 'di')
          .where('di.file_hash IS NOT NULL')
          .getQuery();
        return 'sd.file_hash NOT IN ' + subQuery;
      })
      .orderBy('sd.detected_at', 'DESC');

    const total = await queryBuilder.getCount();
    const data = await queryBuilder
      .skip((page - 1) * limit)
      .take(limit)
      .getMany();

    return {
      data,
      meta: {
        total,
        page,
        limit,
        lastPage: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Import a detected malware file hash to dataset inventories.
   */
  async importToInventory(fileHash: string, labelVal: label = label.MALWARE) {
    const existing = await this.datasetInventoryRepository.findOne({
      where: { file_hash: fileHash },
    });

    if (existing) {
      throw new BadRequestException('File hash already exists in dataset inventory.');
    }

    const scanDetail = await this.scanDetailsRepository.findOne({
      where: { file_hash: fileHash },
    });

    if (!scanDetail) {
      throw new BadRequestException('Scan detail matching the file hash not found.');
    }

    const imported = await this.datasetInventoryRepository.save(
      this.datasetInventoryRepository.create({
        file_hash: fileHash,
        label: labelVal,
        source: DatasetSource.SCAN,
      }),
    );

    return imported;
  }
}
