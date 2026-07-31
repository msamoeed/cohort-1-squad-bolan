import { toIsoString } from '../common/dto/api-response.dto';

export interface ReceivableEntry {
  id?: string;
  type: string;
  contactId: string;
  signedAmount: number;
  occurredAt?: unknown;
  dueDate?: unknown;
  createdAt?: unknown;
}

export interface ContactFinancialSummary {
  currentBalance: number;
  invoiceCount: number;
  earliestDueDate: string | null;
  overdue: boolean;
  overdueBalance: number;
}

interface OutstandingInvoice {
  id: string;
  remainingCents: number;
  dueDate: string | null;
  sortDate: number;
}

export function summarizeReceivablesByContact(
  entries: ReceivableEntry[],
  now = new Date(),
): Map<string, ContactFinancialSummary> {
  const entriesByContact = new Map<string, ReceivableEntry[]>();

  for (const entry of entries) {
    if (!entry.contactId) continue;
    const contactEntries = entriesByContact.get(entry.contactId) ?? [];
    contactEntries.push(entry);
    entriesByContact.set(entry.contactId, contactEntries);
  }

  return new Map(
    [...entriesByContact.entries()].map(([contactId, contactEntries]) => [
      contactId,
      summarizeContactReceivables(contactEntries, now),
    ]),
  );
}

export function summarizeContactReceivables(
  entries: ReceivableEntry[],
  now = new Date(),
): ContactFinancialSummary {
  const invoices: OutstandingInvoice[] = entries
    .filter(
      (entry) => entry.type === 'invoice' && toCents(entry.signedAmount) > 0,
    )
    .map((entry, index) => {
      const dueDate = toIsoString(entry.dueDate);
      const occurredAt = toIsoString(entry.occurredAt);
      const createdAt = toIsoString(entry.createdAt);

      return {
        id: entry.id ?? String(index),
        remainingCents: toCents(entry.signedAmount),
        dueDate,
        sortDate:
          dateValue(dueDate) ??
          dateValue(occurredAt) ??
          dateValue(createdAt) ??
          Number.MAX_SAFE_INTEGER,
      };
    })
    .sort(
      (left, right) =>
        left.sortDate - right.sortDate || left.id.localeCompare(right.id),
    );

  let paymentCents = entries
    .filter((entry) => entry.type === 'payment')
    .reduce(
      (total, entry) => total + Math.max(-toCents(entry.signedAmount), 0),
      0,
    );

  for (const invoice of invoices) {
    if (paymentCents <= 0) break;
    const appliedCents = Math.min(invoice.remainingCents, paymentCents);
    invoice.remainingCents -= appliedCents;
    paymentCents -= appliedCents;
  }

  const outstandingInvoices = invoices.filter(
    (invoice) => invoice.remainingCents > 0,
  );
  const overdueInvoices = outstandingInvoices.filter(
    (invoice) =>
      invoice.dueDate !== null &&
      new Date(invoice.dueDate).getTime() < now.getTime(),
  );

  return {
    currentBalance: fromCents(
      outstandingInvoices.reduce(
        (total, invoice) => total + invoice.remainingCents,
        0,
      ),
    ),
    invoiceCount: invoices.length,
    earliestDueDate:
      outstandingInvoices
        .filter((invoice) => invoice.dueDate !== null)
        .sort((left, right) => left.sortDate - right.sortDate)[0]?.dueDate ??
      null,
    overdue: overdueInvoices.length > 0,
    overdueBalance: fromCents(
      overdueInvoices.reduce(
        (total, invoice) => total + invoice.remainingCents,
        0,
      ),
    ),
  };
}

function toCents(value: number): number {
  return Number.isFinite(value) ? Math.round(value * 100) : 0;
}

function fromCents(value: number): number {
  return value / 100;
}

function dateValue(value: string | null): number | null {
  if (value === null) return null;
  const timestamp = new Date(value).getTime();
  return Number.isNaN(timestamp) ? null : timestamp;
}
