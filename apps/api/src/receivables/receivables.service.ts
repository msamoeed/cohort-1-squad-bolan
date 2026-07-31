import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import {
  DashboardResponseDto,
  InvoiceApprovalResponseDto,
  LedgerEntryResponseDto,
  PaymentResponseDto,
  toIsoString,
} from '../common/dto/api-response.dto';
import { ApproveInvoiceDto, CreatePaymentDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';
import {
  ReceivableEntry,
  summarizeReceivablesByContact,
} from './receivable-calculations';

@Injectable()
export class ReceivablesService {
  constructor(private readonly store: BusinessStoreService) {}

  async approveInvoice(
    businessId: string,
    actorId: string,
    dto: ApproveInvoiceDto,
  ): Promise<InvoiceApprovalResponseDto> {
    const db = this.store.collection(businessId, 'invoices').firestore;
    const extractionRef = this.store
      .collection(businessId, 'invoiceExtractions')
      .doc(dto.extractionId);
    const contactRef = this.store
      .collection(businessId, 'contacts')
      .doc(dto.contactId);
    const invoiceRef = this.store.collection(businessId, 'invoices').doc();
    const entryRef = this.store
      .collection(businessId, 'receivableEntries')
      .doc();
    await db.runTransaction(async (transaction) => {
      const [extraction, contact] = await Promise.all([
        transaction.get(extractionRef),
        transaction.get(contactRef),
      ]);
      if (!extraction.exists)
        throw new NotFoundException('Extraction not found.');
      if (extraction.data()!.status !== 'needs_review')
        throw new ConflictException(
          'Only a draft awaiting review can be approved.',
        );
      if (!contact.exists) throw new NotFoundException('Contact not found.');
      transaction.set(invoiceRef, {
        ...dto,
        status: 'approved',
        approvedBy: actorId,
        approvedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(entryRef, {
        type: 'invoice',
        invoiceId: invoiceRef.id,
        contactId: dto.contactId,
        signedAmount: dto.total,
        occurredAt: dto.invoiceDate,
        dueDate: dto.dueDate ?? null,
        createdBy: actorId,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(extractionRef, {
        status: 'approved',
        approvedInvoiceId: invoiceRef.id,
        approvedAt: FieldValue.serverTimestamp(),
      });
    });
    await this.audit(businessId, actorId, 'invoice.approved', invoiceRef.id);
    return { id: invoiceRef.id, status: 'approved' };
  }

  async recordPayment(
    businessId: string,
    actorId: string,
    contactId: string,
    dto: CreatePaymentDto,
  ): Promise<PaymentResponseDto> {
    const contact = await this.store
      .collection(businessId, 'contacts')
      .doc(contactId)
      .get();
    if (!contact.exists) throw new NotFoundException('Contact not found.');
    const ref = this.store.collection(businessId, 'receivableEntries').doc();
    await ref.set({
      type: 'payment',
      contactId,
      signedAmount: -dto.amount,
      paidAt: dto.paidAt ?? new Date().toISOString(),
      note: dto.note ?? null,
      createdBy: actorId,
      createdAt: FieldValue.serverTimestamp(),
    });
    await this.audit(businessId, actorId, 'payment.recorded', ref.id);
    return { id: ref.id, type: 'payment' };
  }

  async dashboard(businessId: string): Promise<DashboardResponseDto> {
    const snapshot = await this.store
      .collection(businessId, 'receivableEntries')
      .get();
    const summaries = summarizeReceivablesByContact(
      snapshot.docs.map((doc) => toReceivableEntry(doc.id, doc.data())),
    );
    const outstandingSummaries = [...summaries.values()].filter(
      (summary) => summary.currentBalance > 0,
    );

    return {
      outstandingTotal: roundMoney(
        outstandingSummaries.reduce(
          (total, summary) => total + summary.currentBalance,
          0,
        ),
      ),
      overdueTotal: roundMoney(
        outstandingSummaries.reduce(
          (total, summary) => total + summary.overdueBalance,
          0,
        ),
      ),
      customerCount: outstandingSummaries.length,
    };
  }

  async ledger(
    businessId: string,
    contactId: string,
  ): Promise<LedgerEntryResponseDto[]> {
    const [contact, snapshot] = await Promise.all([
      this.store.collection(businessId, 'contacts').doc(contactId).get(),
      this.store
        .collection(businessId, 'receivableEntries')
        .where('contactId', '==', contactId)
        .get(),
    ]);
    if (!contact.exists) throw new NotFoundException('Contact not found.');

    return snapshot.docs
      .map((doc) => toLedgerEntry(doc.id, doc.data()))
      .filter((entry): entry is LedgerEntryResponseDto => entry !== null)
      .sort(
        (left, right) =>
          dateSortValue(left.createdAt ?? left.occurredAt ?? left.paidAt) -
          dateSortValue(right.createdAt ?? right.occurredAt ?? right.paidAt),
      );
  }

  private async audit(
    businessId: string,
    actorId: string,
    action: string,
    resourceId: string,
  ): Promise<void> {
    await this.store.collection(businessId, 'auditEvents').add({
      actorId,
      action,
      resourceId,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
}

function toReceivableEntry(
  id: string,
  data: Record<string, unknown>,
): ReceivableEntry {
  return {
    id,
    type: stringValue(data.type),
    contactId: stringValue(data.contactId),
    signedAmount: Number(data.signedAmount ?? 0),
    occurredAt: data.occurredAt,
    dueDate: data.dueDate,
    createdAt: data.createdAt,
  };
}

function toLedgerEntry(
  id: string,
  data: Record<string, unknown>,
): LedgerEntryResponseDto | null {
  if (data.type !== 'invoice' && data.type !== 'payment') return null;

  return {
    id,
    type: data.type,
    contactId: stringValue(data.contactId),
    signedAmount: Number(data.signedAmount ?? 0),
    invoiceId: typeof data.invoiceId === 'string' ? data.invoiceId : null,
    occurredAt: toIsoString(data.occurredAt),
    dueDate: toIsoString(data.dueDate),
    paidAt: toIsoString(data.paidAt),
    note: typeof data.note === 'string' ? data.note : null,
    createdBy: typeof data.createdBy === 'string' ? data.createdBy : null,
    createdAt: toIsoString(data.createdAt),
  };
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

function dateSortValue(value: string | null): number {
  if (value === null) return Number.MAX_SAFE_INTEGER;
  const timestamp = new Date(value).getTime();
  return Number.isNaN(timestamp) ? Number.MAX_SAFE_INTEGER : timestamp;
}
