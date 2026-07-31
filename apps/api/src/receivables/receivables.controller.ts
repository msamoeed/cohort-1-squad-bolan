import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { DecodedIdToken } from 'firebase-admin/auth';
import {
  DashboardResponseDto,
  InvoiceApprovalResponseDto,
  LedgerEntryResponseDto,
  PaymentResponseDto,
} from '../common/dto/api-response.dto';
import { ApproveInvoiceDto, CreatePaymentDto } from '../common/dto/api.dto';
import { CurrentUser } from '../common/firebase/current-user.decorator';
import { ReceivablesService } from './receivables.service';

@Controller()
export class ReceivablesController {
  constructor(private readonly receivables: ReceivablesService) {}

  @Post('invoices/approve')
  approve(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: ApproveInvoiceDto,
  ): Promise<InvoiceApprovalResponseDto> {
    return this.receivables.approveInvoice(user.uid, user.uid, dto);
  }

  @Post('contacts/:id/payments')
  payment(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') contactId: string,
    @Body() dto: CreatePaymentDto,
  ): Promise<PaymentResponseDto> {
    return this.receivables.recordPayment(user.uid, user.uid, contactId, dto);
  }

  @Get('dashboard')
  dashboard(
    @CurrentUser() user: DecodedIdToken,
  ): Promise<DashboardResponseDto> {
    return this.receivables.dashboard(user.uid);
  }

  @Get('contacts/:id/ledger')
  ledger(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') contactId: string,
  ): Promise<LedgerEntryResponseDto[]> {
    return this.receivables.ledger(user.uid, contactId);
  }
}
