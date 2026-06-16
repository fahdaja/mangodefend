import { Injectable, NotFoundException, BadRequestException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, LessThan } from "typeorm";
import { Transactions } from "../entity/transactions.entity";
import { CreateTransactionDto } from "../dto/create-transaction.dto";
import { TransactionStatus } from "../enum/transaction.enum";
import { Method } from "../enum/method.enum";
import { Plans } from "../../subscriptions/entity/subscription.entity";
import { User } from "../../users/entity/user.entity";
import { SubscriptionService } from "../../subscriptions/service/subscription.service";
import { MailService } from "../../../common/mail/mail.service";

@Injectable()
export class TransactionService {
    constructor(
        @InjectRepository(Transactions)
        private transactionRepository: Repository<Transactions>,
        @InjectRepository(Plans)
        private planRepository: Repository<Plans>,
        @InjectRepository(User)
        private userRepository: Repository<User>,
        private subscriptionService: SubscriptionService,
        private mailService: MailService
    ) {}

    async createTransaction(data: CreateTransactionDto): Promise<any> {
        // Cek apakah plan valid
        const plan = await this.planRepository.findOne({ where: { id: data.plan_id } });
        if (!plan) {
            throw new NotFoundException('Plan not found');
        }

        // Buat record transaksi dengan status PENDING
        const transaction = this.transactionRepository.create({
            user_id: data.user_id,
            plan_id: data.plan_id,
            amount: plan.price,
            method: data.method,
            status: TransactionStatus.PENDING
        });

        const savedTransaction = await this.transactionRepository.save(transaction);
        
        return {
            status: 'success',
            message: 'Transaction created successfully. Please complete the payment.',
            data: savedTransaction
        };
    }

    // Ubah status transaksi secara umum dan picu efek samping jika sukses
    async processTransactionUpdate(transactionId: number, status: TransactionStatus, method?: string): Promise<any> {
        const transaction = await this.transactionRepository.findOne({ where: { id: transactionId } });
        if (!transaction) {
            throw new NotFoundException('Transaction not found');
        }

        // Jika transaksi sudah sukses sebelumnya, jangan ubah statusnya lagi
        if (transaction.status === TransactionStatus.SUCCESS) {
            return {
                status: 'success',
                message: 'Transaction is already marked as SUCCESS.',
                data: transaction
            };
        }

        // Update status & metode pembayaran jika dikirimkan oleh payment gateway
        transaction.status = status;
        if (method) {
            const cleanMethod = method.toLowerCase();
            if (cleanMethod.includes('qris')) {
                transaction.method = Method.QRIS;
            } else {
                transaction.method = Method.VIRTUAL_ACCOUNT;
            }
        }

        await this.transactionRepository.save(transaction);

        // Jika status baru adalah SUCCESS, aktifkan subscription dan kirim email bukti bayar
        if (status === TransactionStatus.SUCCESS) {
            await this.subscriptionService.createSubscription({
                user_id: transaction.user_id,
                plan_id: transaction.plan_id
            });

            try {
                const user = await this.userRepository.findOne({ where: { id: transaction.user_id } });
                const plan = await this.planRepository.findOne({ where: { id: transaction.plan_id } });
                if (user && plan) {
                    this.mailService.sendReceiptEmail({
                        email: user.email,
                        transactionId: transaction.id,
                        planName: plan.plan_name,
                        amount: Number(transaction.amount),
                        durationDays: plan.durationDays,
                        paymentMethod: transaction.method || 'qris',
                    }).catch(err => {
                        console.error('Failed to send receipt email background promise:', err);
                    });
                }
            } catch (mailError) {
                console.error('Failed to initiate sending receipt email:', mailError);
            }
        }

        return {
            status: 'success',
            message: `Transaction status updated to ${status} successfully.`,
            data: transaction
        };
    }

    // Endpoint simulasi webhook sukses (tetap dipertahankan untuk backward compatibility)
    async simulatePaymentSuccess(transactionId: number): Promise<any> {
        return this.processTransactionUpdate(transactionId, TransactionStatus.SUCCESS);
    }

    // Handler Webhook Standar Industri (Mendukung Payload Midtrans / Xendit / Simulasi Custom)
    async handleWebhookNotification(payload: any): Promise<any> {
        const transactionIdStr = payload.order_id || payload.transaction_id;
        if (!transactionIdStr) {
            throw new BadRequestException('Transaction ID or Order ID is required');
        }

        // Ekstrak angka dari order_id (contoh: "tx-12" menjadi 12)
        const transactionId = typeof transactionIdStr === 'number'
            ? transactionIdStr
            : parseInt(transactionIdStr.toString().replace(/\D/g, ''), 10);

        if (isNaN(transactionId)) {
            throw new BadRequestException('Invalid Transaction ID format');
        }

        // Petakan status input payment gateway ke internal TransactionStatus
        let targetStatus: TransactionStatus;
        const incomingStatus = (payload.transaction_status || payload.status || '').toLowerCase();

        switch (incomingStatus) {
            case 'settlement':
            case 'capture':
            case 'success':
                targetStatus = TransactionStatus.SUCCESS;
                break;
            case 'expire':
            case 'expired':
                targetStatus = TransactionStatus.EXPIRED;
                break;
            case 'deny':
            case 'cancel':
            case 'failure':
            case 'failed':
                targetStatus = TransactionStatus.FAILED;
                break;
            case 'pending':
                targetStatus = TransactionStatus.PENDING;
                break;
            default:
                throw new BadRequestException(`Unknown transaction status: ${payload.transaction_status || payload.status}`);
        }

        const paymentMethod = payload.payment_type || payload.method;
        return this.processTransactionUpdate(transactionId, targetStatus, paymentMethod);
    }

    // Menandai transaksi PENDING yang berumur lebih dari 24 jam sebagai EXPIRED secara otomatis
    async autoExpirePendingTransactions(): Promise<void> {
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1); // 24 jam yang lalu

        const oldPendingTransactions = await this.transactionRepository.find({
            where: {
                status: TransactionStatus.PENDING,
                created_at: LessThan(oneDayAgo)
            }
        });

        if (oldPendingTransactions.length > 0) {
            for (const tx of oldPendingTransactions) {
                tx.status = TransactionStatus.EXPIRED;
                await this.transactionRepository.save(tx);
            }
        }
    }

    async findAllTransactions(): Promise<any> {
        // Lakukan pembersihan transaksi kedaluwarsa secara otomatis
        await this.autoExpirePendingTransactions();

        const transactions = await this.transactionRepository.find({
            relations: ['user', 'plan'],
            order: { created_at: 'DESC' }
        });
        return {
            status: 'success',
            data: transactions
        };
    }
}
