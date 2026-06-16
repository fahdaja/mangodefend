import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Transactions } from './entity/transactions.entity';
import { Plans, Subscriptions } from '../subscriptions/entity/subscription.entity';
import { User } from '../users/entity/user.entity';
import { TransactionController } from './controllers/transaction.controller';
import { TransactionService } from './services/transaction.service';
import { SubscriptionModule } from '../subscriptions/subscription.module';
import { AuthModule } from '../auth/auth.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Transactions, Plans, Subscriptions, User]),
        AuthModule,
        SubscriptionModule
    ],
    controllers: [TransactionController],
    providers: [TransactionService],
    exports: [TransactionService]
})
export class TransactionModule {}