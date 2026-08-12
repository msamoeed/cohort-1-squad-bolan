import { Injectable, NotFoundException } from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import {
  ContactSummaryResponseDto,
  IdResponseDto,
  toIsoString,
} from '../common/dto/api-response.dto';
import { CreateContactDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';
import {
  ContactFinancialSummary,
  ReceivableEntry,
  summarizeContactReceivables,
  summarizeReceivablesByContact,
} from '../receivables/receivable-calculations';

@Injectable()
export class ContactsService {
  constructor(private readonly store: BusinessStoreService) {}

  async create(
    businessId: string,
    dto: CreateContactDto,
  ): Promise<IdResponseDto> {
    const ref = this.store.collection(businessId, 'contacts').doc();
    // Explicit fields only: spreading the DTO writes `undefined` for an
    // omitted email, which Firestore rejects.
    await ref.set({
      name: dto.name.trim(),
      phone: dto.phone.trim(),
      email: dto.email?.trim() || null,
      whatsappOptIn: dto.whatsappOptIn ?? false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { id: ref.id };
  }

  async list(businessId: string): Promise<ContactSummaryResponseDto[]> {
    const [contactsSnapshot, entriesSnapshot] = await Promise.all([
      this.store.collection(businessId, 'contacts').orderBy('name').get(),
      this.store.collection(businessId, 'receivableEntries').get(),
    ]);
    const summaries = summarizeReceivablesByContact(
      entriesSnapshot.docs.map((doc) => toReceivableEntry(doc.id, doc.data())),
    );

    return contactsSnapshot.docs.map((doc) =>
      toContactSummary(
        doc.id,
        doc.data(),
        summaries.get(doc.id) ?? emptySummary(),
      ),
    );
  }

  async get(
    businessId: string,
    id: string,
  ): Promise<ContactSummaryResponseDto> {
    const [contactSnapshot, entriesSnapshot] = await Promise.all([
      this.store.collection(businessId, 'contacts').doc(id).get(),
      this.store
        .collection(businessId, 'receivableEntries')
        .where('contactId', '==', id)
        .get(),
    ]);
    if (!contactSnapshot.exists)
      throw new NotFoundException('Contact not found.');
    const summary = summarizeContactReceivables(
      entriesSnapshot.docs.map((doc) => toReceivableEntry(doc.id, doc.data())),
    );
    return toContactSummary(
      contactSnapshot.id,
      contactSnapshot.data()!,
      summary,
    );
  }
}

function toContactSummary(
  id: string,
  data: Record<string, unknown>,
  summary: ContactFinancialSummary,
): ContactSummaryResponseDto {
  return {
    id,
    name: stringValue(data.name),
    phone: stringValue(data.phone),
    email: typeof data.email === 'string' ? data.email : null,
    whatsappOptIn: data.whatsappOptIn === true,
    createdAt: toIsoString(data.createdAt),
    updatedAt: toIsoString(data.updatedAt),
    currentBalance: summary.currentBalance,
    invoiceCount: summary.invoiceCount,
    earliestDueDate: summary.earliestDueDate,
    overdue: summary.overdue,
  };
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

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function emptySummary(): ContactFinancialSummary {
  return {
    currentBalance: 0,
    invoiceCount: 0,
    earliestDueDate: null,
    overdue: false,
    overdueBalance: 0,
  };
}
