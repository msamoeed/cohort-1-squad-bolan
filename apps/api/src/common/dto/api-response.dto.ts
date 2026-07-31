export class IdResponseDto {
  id!: string;
}

export class ContactSummaryResponseDto {
  id!: string;
  name!: string;
  phone!: string;
  email!: string | null;
  whatsappOptIn!: boolean;
  createdAt!: string | null;
  updatedAt!: string | null;
  currentBalance!: number;
  invoiceCount!: number;
  earliestDueDate!: string | null;
  overdue!: boolean;
}

export class DashboardResponseDto {
  outstandingTotal!: number;
  overdueTotal!: number;
  customerCount!: number;
}

export type LedgerEntryType = 'invoice' | 'payment';

export class LedgerEntryResponseDto {
  id!: string;
  type!: LedgerEntryType;
  contactId!: string;
  signedAmount!: number;
  invoiceId!: string | null;
  occurredAt!: string | null;
  dueDate!: string | null;
  paidAt!: string | null;
  note!: string | null;
  createdBy!: string | null;
  createdAt!: string | null;
}

export class UploadResponseDto {
  id!: string;
  sha256!: string;
  status!: 'uploaded';
}

export type InvoiceExtractionStatus =
  'processing' | 'needs_review' | 'approved' | 'failed';

export class InvoiceExtractionResponseDto {
  id!: string;
  uploadId!: string;
  status!: InvoiceExtractionStatus;
  model!: string;
  promptVersion!: string;
  draft!: unknown;
  failureReason!: string | null;
  approvedInvoiceId!: string | null;
  createdAt!: string | null;
  completedAt!: string | null;
  approvedAt!: string | null;
}

export class InvoiceApprovalResponseDto {
  id!: string;
  status!: 'approved';
}

export class PaymentResponseDto {
  id!: string;
  type!: 'payment';
}

export class ReminderDraftResponseDto {
  id!: string;
  message!: string;
  whatsappUrl!: string;
}

export function toIsoString(value: unknown): string | null {
  if (value == null) return null;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  if (typeof value === 'object' && hasToDate(value)) {
    return value.toDate().toISOString();
  }
  if (typeof value === 'object') {
    const timestamp = value as { _seconds?: unknown; seconds?: unknown };
    const seconds = Number(timestamp._seconds ?? timestamp.seconds);
    if (Number.isFinite(seconds)) return new Date(seconds * 1000).toISOString();
  }
  return null;
}

function hasToDate(value: object): value is { toDate: () => Date } {
  if (!('toDate' in value)) return false;
  return typeof (value as { toDate?: unknown }).toDate === 'function';
}
