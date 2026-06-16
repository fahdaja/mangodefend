import { Injectable, NotFoundException, BadRequestException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, LessThan } from "typeorm";
import { Plans, Subscriptions, SubscriptionStatus } from "../entity/subscription.entity";
import { CreatePlanDto } from "../dto/create-plan.dto";
import { CreateSubscriptionDto } from "../dto/create-subscription.dto";

@Injectable()
export class SubscriptionService {
    constructor(
        @InjectRepository(Subscriptions)
        private subscriptionRepository: Repository<Subscriptions>,
        @InjectRepository(Plans)
        private planRepository: Repository<Plans>
    ) {}

    // Otomatis menonaktifkan langganan yang masa end_date nya sudah terlewati
    async autoExpireSubscriptions(): Promise<void> {
        const now = new Date();
        const expiredSubs = await this.subscriptionRepository.find({
            where: {
                is_active: true,
                end_date: LessThan(now)
            }
        });

        if (expiredSubs.length > 0) {
            for (const sub of expiredSubs) {
                sub.is_active = false;
                sub.status = SubscriptionStatus.EXPIRED;
                await this.subscriptionRepository.save(sub);
            }
        }
    }

    // tampilkan list subscription yang aktif
    async findAllActiveSubscription(userId: number): Promise<Subscriptions[]> {
        await this.autoExpireSubscriptions();
        return await this.subscriptionRepository.find({
            where: { user_id: userId, is_active: true },
            relations: ['plan', 'plan.model']
        });
    }

    // tampilkan list subscription berikut user yang
    async findAllSubscriptionsWithUser(): Promise<Subscriptions[]> {
        await this.autoExpireSubscriptions();
        return await this.subscriptionRepository.find({
            relations: ['user', 'plan', 'plan.model'],
            order: { end_date: 'DESC' }
        });
    }

    // admin buat card plan dari setiap subscription
    async createPlan(data: CreatePlanDto): Promise<any> {
        const plan = this.planRepository.create(data);
        const savedPlan = await this.planRepository.save(plan);
        return {
            status: 'success',
            message: 'Plan created successfully',
            data: savedPlan
        };
    }

    async findAllPlans(): Promise<Plans[]> {
        const plansData = await this.planRepository.find({
            relations: ['model'],
        });
        return Object.values(plansData);
    }

    // buat data user yang melakukan subscription berdasarkan plan yang dipilih
    // lalu arahkan ke transaction
    async createSubscription(data: CreateSubscriptionDto): Promise<Subscriptions> {
        const plan = await this.planRepository.findOne({ where: { id: data.plan_id } });
        if (!plan) {
            throw new NotFoundException('Plan not found');
        }

        // Cari apakah user sudah punya subscription yang masih aktif (diambil yang tenggat waktunya paling lama)
        const existingSubscription = await this.subscriptionRepository.findOne({
            where: { user_id: data.user_id, is_active: true },
            order: { end_date: 'DESC' }
        });

        if (existingSubscription && existingSubscription.end_date > new Date()) {
            if (existingSubscription.plan_id !== data.plan_id) {
                // LOGIKA OVERRIDE: User mengganti plan (misal Free ke Pro)
                // Matikan langganan yang lama dengan status REPLACED
                existingSubscription.is_active = false;
                existingSubscription.status = SubscriptionStatus.REPLACED;
                await this.subscriptionRepository.save(existingSubscription);

                // Buat langganan baru yang langsung aktif hari ini
                const end_date = new Date();
                end_date.setDate(end_date.getDate() + plan.durationDays);

                const newSubscription = this.subscriptionRepository.create({
                    user_id: data.user_id,
                    plan_id: data.plan_id,
                    start_date: new Date(),
                    end_date: end_date,
                    is_active: true,
                    status: SubscriptionStatus.ACTIVE
                });

                return await this.subscriptionRepository.save(newSubscription);
            }

            // LOGIKA RENEWAL: User membeli plan yang SAMA
            // Tambahkan durasi ke end_date yang sudah ada
            const newEndDate = new Date(existingSubscription.end_date);
            newEndDate.setDate(newEndDate.getDate() + plan.durationDays);
            
            existingSubscription.end_date = newEndDate;
            existingSubscription.status = SubscriptionStatus.ACTIVE;
            return await this.subscriptionRepository.save(existingSubscription);

        } else {
            // Jika belum ada langganan atau sudah kedaluwarsa, buat baru
            const end_date = new Date();
            end_date.setDate(end_date.getDate() + plan.durationDays);

            const subscription = this.subscriptionRepository.create({
                user_id: data.user_id,
                plan_id: data.plan_id,
                start_date: new Date(),
                end_date: end_date,
                is_active: true,
                status: SubscriptionStatus.ACTIVE
            });

            return await this.subscriptionRepository.save(subscription);
        }
    }
    
   async updatePlan(id: number, data: Partial<CreatePlanDto>): Promise<Plans> {
        // 1. Cek apakah plan-nya ada
        const plan = await this.planRepository.findOne({ where: { id } });
        if (!plan) {
            throw new NotFoundException(`Plan dengan ID ${id} tidak ditemukan`);
        }

        // 2. Gunakan Object.assign atau preload untuk update
        const updatedPlan = Object.assign(plan, data);
        
        // 3. Simpan dan kembalikan data yang sudah berubah
        return await this.planRepository.save(updatedPlan);
    }

    async deletePlan(id: number): Promise<any> {
        // 1. Cari plan-nya dulu
        const plan = await this.planRepository.findOne({ where: { id } });
        if (!plan) {
            throw new NotFoundException(`Plan dengan ID ${id} tidak ditemukan`);
        }

        // 2. Cek apakah ada user yang sudah terlanjur berlangganan plan ini
        const subscriptionCount = await this.subscriptionRepository.count({ 
            where: { plan_id: id } 
        });

        if (subscriptionCount > 0) {
            // Jika ada relasi, lempar BadRequest (Jangan asal hapus data sejarah)
            throw new BadRequestException(
                `Gagal hapus! Plan ini masih digunakan oleh ${subscriptionCount} data langganan user.`
            );
        }

        // 3. Jika benar-benar bersih, baru delete
        await this.planRepository.delete(id);
        
        return {
            status: 'success',
            message: 'Plan berhasil dihapus'
        };
    }
}