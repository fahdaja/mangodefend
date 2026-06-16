import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MlModel } from '../entity/ml.entity';
import { Plans, Subscriptions } from '../../subscriptions/entity/subscription.entity';
import { CreateMlModelDto } from '../dto/create-ml.dto';

@Injectable()
export class MlService {
  constructor(
    @InjectRepository(MlModel)
    private mlModelRepository: Repository<MlModel>,
    @InjectRepository(Subscriptions)
    private subscriptionRepository: Repository<Subscriptions>,
    @InjectRepository(Plans)
    private planRepository: Repository<Plans>,
  ) {}

  async createModel(data: CreateMlModelDto): Promise<any> {
    const existingModel = await this.mlModelRepository.findOne({
      where: { version: data.version },
    });
    if (existingModel) {
      throw new ConflictException(
        `Model with version ${data.version} already exists`,
      );
    }

    const model = this.mlModelRepository.create(data);
    const savedModel = await this.mlModelRepository.save(model);

    return {
      status: 'success',
      message: 'Model created successfully',
      data: savedModel,
    };
  }

  async findAllModels(): Promise<any> {
    const models = await this.mlModelRepository.find({
      order: { created_at: 'DESC' },
    });
    return {
      status: 'success',
      data: models,
    };
  }

  async toggleModelStatus(id: number, is_active: boolean): Promise<any> {
    const model = await this.mlModelRepository.findOne({ where: { id } });
    if (!model) {
      throw new NotFoundException('Model not found');
    }
    if (is_active) {
      await this.mlModelRepository.update({}, { is_active: false });
    }

    model.is_active = is_active;
    await this.mlModelRepository.save(model);

    return {
      status: 'success',
      message: `Model status updated to ${is_active ? 'active' : 'inactive'}`,
      data: model,
    };
  }

  async deleteModel(id: number): Promise<any> {
    const model = await this.mlModelRepository.findOne({ where: { id } });
    if (!model) {
      throw new NotFoundException('Model not found');
    }

    await this.mlModelRepository.remove(model);

    return {
      status: 'success',
      message: 'Model deleted successfully',
      data: model,
    };
  }

  async findActiveModelForUser(userId: number): Promise<MlModel> {
    // 1. Cari active subscription milik user
    const activeSub = await this.subscriptionRepository.findOne({
      where: { user_id: userId, is_active: true },
      relations: ['plan', 'plan.model'],
      order: { end_date: 'DESC' },
    });

    // 2. Jika subscription ditemukan dan paketnya menunjuk ke ML Model tertentu, return model tsb
    if (activeSub && activeSub.plan && activeSub.plan.model) {
      return activeSub.plan.model;
    }

    // 3. Fallback: ambil model aktif terbaru secara global di sistem
    const latestActiveModel = await this.mlModelRepository.findOne({
      where: { is_active: true },
      order: { created_at: 'DESC' },
    });

    if (!latestActiveModel) {
      throw new NotFoundException('No active antivirus model found on the system');
    }

    return latestActiveModel;
  }
}
