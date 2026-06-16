import {
  Injectable,
  BadRequestException,
  ConflictException,
  HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { User, Device } from '../entity/user.entity';
import { Repository } from 'typeorm';
import { BcryptService } from '../../../common/hash/bcrypt.service';
import { CreateUserDto } from '../dto/user.dto';
import { application_type, os_type } from '../enum/devices.enum';
import { AuthProvider } from '../enum/auth-provider.enum';
import { Plans, Subscriptions } from '../../subscriptions/entity/subscription.entity';
import { PlanType } from '../../subscriptions/enum/plan.enum';

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(Device)
    private readonly deviceRepository: Repository<Device>,
    @InjectRepository(Plans)
    private readonly planRepository: Repository<Plans>,
    @InjectRepository(Subscriptions)
    private readonly subscriptionRepository: Repository<Subscriptions>,
    private readonly bcryptService: BcryptService,
  ) {}

  async findAll(search?: string, page: number = 1, limit: number = 10) {
    const queryBuilder = this.userRepository.createQueryBuilder('user');

    queryBuilder
      .leftJoin('user.devices', 'device')
      .leftJoin('user.subscriptions', 'subscription')
      .select([
        'user.id AS id',
        'user.email AS email',
        'user.role AS role',
        'user.createdAt AS "createdAt"',
      ])
      .addSelect('COUNT(DISTINCT device.id)', 'deviceCount')
      .addSelect('COUNT(DISTINCT subscription.id)', 'subCount')
      .groupBy('user.id')
      .addGroupBy('user.email')
      .addGroupBy('user.role')
      .addGroupBy('user.createdAt');

    if (search) {
      queryBuilder.andWhere(
        // PERBAIKAN: Gunakan kutip ganda pada "user" karena itu reserved keyword
        '("user".email ILIKE :search OR "user".role::text ILIKE :search)',
        { search: `%${search}%` },
      );
    }

    queryBuilder
      // PERBAIKAN: Gunakan kutip ganda pada "user" di orderBy juga
      .orderBy('"user"."createdAt"', 'DESC')
      .offset((page - 1) * limit)
      .limit(limit);

    const rawResults = await queryBuilder.getRawMany();

    // Hitung total untuk pagination (Jangan lupa kutipnya juga di sini)
    const countQuery = this.userRepository.createQueryBuilder('user');
    if (search) {
      countQuery.andWhere(
        '("user".email ILIKE :search OR "user".role::text ILIKE :search)',
        { search: `%${search}%` },
      );
    }
    const total = await countQuery.getCount();

    const data = rawResults.map((res) => ({
      id: res.id,
      email: res.email,
      role: res.role,
      createdAt: res.createdAt,
      devices: { length: parseInt(res.deviceCount) || 0 },
      subscriptions: { length: parseInt(res.subCount) || 0 },
    }));

    return {
      data,
      meta: { total, page, lastPage: Math.ceil(total / limit) },
    };
  }

  /**
   * Hitung total user, admin, dan client dalam 1x panggil database
   */
  async getDashboardStats() {
    const stats = await this.userRepository
      .createQueryBuilder('user')
      .select('COUNT(user.id)', 'total')
      .addSelect("COUNT(CASE WHEN user.role = 'admin' THEN 1 END)", 'admins')
      .addSelect("COUNT(CASE WHEN user.role = 'client' THEN 1 END)", 'clients')
      .getRawOne();

    return {
      total: parseInt(stats.total),
      admins: parseInt(stats.admins),
      clients: parseInt(stats.clients),
    };
  }

  async createUser(createUserDto: CreateUserDto): Promise<User> {
    const existingUser = await this.userRepository.findOne({
      where: { email: createUserDto.email },
    });
    if (existingUser) {
      throw new ConflictException('Email already exists');
    }
    const newUser = this.userRepository.create(createUserDto);
    newUser.password = await this.bcryptService.hashPassword(
      createUserDto.password,
    );
    const savedUser = await this.userRepository.save(newUser);

    // Auto-assign Free Plan
    try {
      const freePlan = await this.planRepository.findOne({
        where: { plan_name: PlanType.FREE },
      });
      if (freePlan) {
        const end_date = new Date();
        end_date.setDate(end_date.getDate() + freePlan.durationDays);

        const subscription = this.subscriptionRepository.create({
          user_id: savedUser.id,
          plan_id: freePlan.id,
          start_date: new Date(),
          end_date: end_date,
          is_active: true,
        });
        await this.subscriptionRepository.save(subscription);
      }
    } catch (err) {
      console.error('Failed to assign free plan on user registration:', err);
    }

    return savedUser;
  }

  async recordUserDevice(
    userId: number,
    deviceData: {
      hardware_id: string;
      hostname: string;
      os_type: os_type;
      app_type: application_type;
      last_login: Date | null;
      last_active: Date | null;
      is_active: boolean;
    },
  ): Promise<Device> {
    const existingDevice = await this.deviceRepository.findOne({
      where: { user_id: userId, hardware_id: deviceData.hardware_id },
    });

    const now = new Date();

    if (existingDevice) {
      Object.assign(existingDevice, deviceData);

      if (deviceData.is_active === true) {
        existingDevice.last_login = now;
      } else {
        existingDevice.last_active = now;
      }

      return await this.deviceRepository.save(existingDevice);
    } else {
      const newDevice = this.deviceRepository.create({
        ...deviceData,
        user_id: userId,
        last_login: now,
        last_active: null,
      });
      return await this.deviceRepository.save(newDevice);
    }
  }

  async findUserDevices(userId: number) {
    return await this.deviceRepository.find({
      where: { user_id: userId },
      order: { last_login: 'DESC' },
    });
  }

  async findDevice(userId: number, hardwareId: string): Promise<Device | null> {
    return await this.deviceRepository.findOne({
      where: { user_id: userId, hardware_id: hardwareId },
    });
  }

  async findByEmail(email: string): Promise<User | null> {
    return await this.userRepository.findOne({ where: { email } });
  }

  async findById(id: number): Promise<User | null> {
    return await this.userRepository.findOne({ where: { id } });
  }

  async findByFirebaseUid(firebaseUid: string): Promise<User | null> {
    return await this.userRepository.findOne({
      where: { firebase_uid: firebaseUid },
    });
  }

  /**
   * Find user by Firebase UID or email, or create a new one.
   * Used during Firebase OAuth login flow.
   */
  async findOrCreateFirebaseUser(data: {
    firebase_uid: string;
    email: string;
    auth_provider: AuthProvider;
    display_name?: string;
    photo_url?: string;
  }): Promise<{ user: User; isNewUser: boolean }> {
    // 1. Cari berdasarkan firebase_uid dulu
    let user = await this.findByFirebaseUid(data.firebase_uid);
    if (user) {
      // Update info terbaru dari Firebase
      if (data.display_name) user.display_name = data.display_name;
      if (data.photo_url) user.photo_url = data.photo_url;
      await this.userRepository.save(user);
      return { user, isNewUser: false };
    }

    // 2. Cari berdasarkan email (mungkin user sudah register manual sebelumnya)
    user = await this.findByEmail(data.email);
    if (user) {
      // Link akun existing dengan Firebase
      user.firebase_uid = data.firebase_uid;
      user.auth_provider = data.auth_provider;
      if (data.display_name && !user.display_name)
        user.display_name = data.display_name;
      if (data.photo_url && !user.photo_url) user.photo_url = data.photo_url;
      await this.userRepository.save(user);
      return { user, isNewUser: false };
    }

    // 3. Buat user baru
    const newUser = this.userRepository.create({
      email: data.email,
      password: null,
      firebase_uid: data.firebase_uid,
      auth_provider: data.auth_provider,
      display_name: data.display_name || null,
      photo_url: data.photo_url || null,
    });
    const savedUser = await this.userRepository.save(newUser);

    // Auto-assign Free Plan
    try {
      const freePlan = await this.planRepository.findOne({
        where: { plan_name: PlanType.FREE },
      });
      if (freePlan) {
        const end_date = new Date();
        end_date.setDate(end_date.getDate() + freePlan.durationDays);

        const subscription = this.subscriptionRepository.create({
          user_id: savedUser.id,
          plan_id: freePlan.id,
          start_date: new Date(),
          end_date: end_date,
          is_active: true,
        });
        await this.subscriptionRepository.save(subscription);
      }
    } catch (err) {
      console.error('Failed to assign free plan on Firebase user registration:', err);
    }

    return { user: savedUser, isNewUser: true };
  }
}
