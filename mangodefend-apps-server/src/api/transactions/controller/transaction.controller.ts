import { Controller, Post, Body, Param, ParseIntPipe, UseGuards, Req, Get } from '@nestjs/common';
import { TransactionService } from '../service/transaction.service';
import { CreateTransactionDto } from '../dto/create-transaction.dto';
import { AuthGuard } from '../../auth/guard/auth.guard';
import { RoleGuard } from '../../auth/guard/roles.guard';
import { Roles } from '../../../common/decorator/roles.decorator';
import { Role } from '../../users/enum/roles.enum';

@Controller('transactions')
export class TransactionController {
    constructor(private readonly transactionService: TransactionService) {}

    @UseGuards(AuthGuard, RoleGuard)
    @Roles(Role.ADMIN)
    @Get()
    async getAllTransactions() {
        return this.transactionService.findAllTransactions();
    }

    @UseGuards(AuthGuard, RoleGuard)
    @Roles(Role.CLIENT)
    @Post('checkout')
    async checkout(@Body() createTransactionDto: CreateTransactionDto, @Req() req: any) {
        createTransactionDto.user_id = req.user.id;
        return this.transactionService.createTransaction(createTransactionDto);
    }

    // Endpoint simulasi Webhook/Callback dari Payment Gateway
    @Post('webhook/success/:id')
    async simulatePaymentSuccess(@Param('id', ParseIntPipe) transactionId: number) {
        return this.transactionService.simulatePaymentSuccess(transactionId);
    }

    // Webhook Resmi / Terpadu untuk menerima notifikasi dari Payment Gateway (e.g. Midtrans)
    @Post('webhook')
    async handleWebhookNotification(@Body() payload: any) {
        return this.transactionService.handleWebhookNotification(payload);
    }
}
