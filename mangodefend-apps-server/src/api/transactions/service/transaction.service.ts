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
import { ConfigService } from "@nestjs/config";
import { RabbitMQService, QUEUES } from "../../../common/rabbitmq/rabbitmq.service";
import axios from "axios";

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
        private mailService: MailService,
        private configService: ConfigService,
        private rabbitMQService: RabbitMQService,
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

        let savedTransaction = await this.transactionRepository.save(transaction);
        
        // Integrasi Midtrans Core/Snap API
        const serverKey = this.configService.get<string>('MIDTRANS_SERVER_KEY');
        if (serverKey) {
            const isProduction = this.configService.get<string>('MIDTRANS_IS_PRODUCTION') === 'true';
            const apiBaseUrl = isProduction
                ? 'https://api.midtrans.com'
                : 'https://api.sandbox.midtrans.com';

            const authHeader = 'Basic ' + Buffer.from(serverKey + ':').toString('base64');
            const orderId = `MANGODEFEND-TX-${savedTransaction.id}`;

            try {
                let chargePayload: any = {
                    transaction_details: {
                        order_id: orderId,
                        gross_amount: Math.round(Number(plan.price))
                    }
                };

                if (data.method === Method.QRIS) {
                    chargePayload = {
                        ...chargePayload,
                        payment_type: 'qris',
                        qris: {
                            acquirer: 'gopay'
                        }
                    };
                } else {
                    chargePayload = {
                        ...chargePayload,
                        payment_type: 'bank_transfer',
                        bank_transfer: {
                            bank: 'bca'
                        }
                    };
                }

                const response = await axios.post(`${apiBaseUrl}/v2/charge`, chargePayload, {
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                        'Authorization': authHeader
                    }
                });

                if (response.data) {
                    savedTransaction.external_id = response.data.transaction_id || null;
                    savedTransaction.payment_details = response.data;
                    
                    // Hubungi Snap API juga untuk mendapatkan redirect_url yang bisa dibuka di browser
                    const snapUrl = isProduction
                        ? 'https://app.midtrans.com/snap/v1/transactions'
                        : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
                    
                    try {
                        const user = await this.userRepository.findOne({ where: { id: data.user_id } });
                        const snapResponse = await axios.post(snapUrl, {
                            transaction_details: {
                                order_id: orderId,
                                gross_amount: Math.round(Number(plan.price))
                            },
                            customer_details: user ? {
                                email: user.email
                            } : undefined
                        }, {
                            headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json',
                                'Authorization': authHeader
                            }
                        });
                        
                        if (snapResponse.data) {
                            savedTransaction.redirect_url = snapResponse.data.redirect_url;
                        }
                    } catch (snapError: any) {
                        console.error('Failed to pre-fetch Midtrans Snap redirect_url:', snapError.message);
                    }

                    savedTransaction = await this.transactionRepository.save(savedTransaction);
                }
            } catch (error: any) {
                console.error('Midtrans payment charge failed:', error.response?.data || error.message);
            }
        }
        
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

        // Jika status baru adalah SUCCESS, aktifkan subscription via PaymentWorker / sync fallback
        if (status === TransactionStatus.SUCCESS) {
            const published = await this.rabbitMQService.publish(QUEUES.PAYMENT_EVENTS, {
                transactionId: transaction.id,
                userId: transaction.user_id,
                planId: transaction.plan_id,
                amount: Number(transaction.amount),
                paymentMethod: transaction.method || 'qris',
            });

            if (!published) {
                // Synchronous fallback if RabbitMQ is not available
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

        // Ekstrak angka dari order_id (contoh: "tx-12" atau "MANGODEFEND-TX-12" menjadi 12)
        const transactionId = typeof transactionIdStr === 'number'
            ? transactionIdStr
            : parseInt(transactionIdStr.toString().replace(/\D/g, ''), 10);

        if (isNaN(transactionId)) {
            throw new BadRequestException('Invalid Transaction ID format');
        }

        // Verifikasi Signature jika MIDTRANS_SERVER_KEY terkonfigurasi dan signature_key dikirim
        const serverKey = this.configService.get<string>('MIDTRANS_SERVER_KEY');
        if (serverKey && payload.signature_key) {
            const crypto = require('crypto');
            const orderId = payload.order_id;
            const statusCode = payload.status_code;
            const grossAmount = payload.gross_amount;
            const rawString = `${orderId}${statusCode}${grossAmount}${serverKey}`;
            const calculatedSignature = crypto.createHash('sha512').update(rawString).digest('hex');

            if (calculatedSignature !== payload.signature_key) {
                console.error('Invalid signature key from Midtrans webhook');
                throw new BadRequestException('Invalid webhook signature');
            }
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
