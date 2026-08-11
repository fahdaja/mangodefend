import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { dataset_inventories } from '../entity/dataset.entity';
import { label } from '../enum/label.enum';

@Injectable()
export class DatasetService {
  constructor(
    @InjectRepository(dataset_inventories)
    private readonly datasetInventoryRepository: Repository<dataset_inventories>,
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
}
