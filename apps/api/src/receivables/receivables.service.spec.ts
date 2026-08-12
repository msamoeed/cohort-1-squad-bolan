import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { FieldValue } from 'firebase-admin/firestore';
import { ApproveInvoiceDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';
import { ReceivablesService } from './receivables.service';

describe('ReceivablesService', () => {
  it('calculates dashboard totals from remaining invoice balances', async () => {
    const entriesSnapshot = {
      docs: [
        ledgerDoc(
          'invoice-1',
          'invoice',
          'contact-1',
          100,
          '2020-01-01T00:00:00.000Z',
        ),
        ledgerDoc('payment-1', 'payment', 'contact-1', -30),
        ledgerDoc(
          'invoice-2',
          'invoice',
          'contact-2',
          50,
          '2099-01-01T00:00:00.000Z',
        ),
        ledgerDoc('payment-2', 'payment', 'contact-2', -10),
        ledgerDoc(
          'invoice-3',
          'invoice',
          'contact-3',
          20,
          '2020-01-01T00:00:00.000Z',
        ),
        ledgerDoc('payment-3', 'payment', 'contact-3', -20),
      ],
    };
    const store = {
      collection: jest.fn(() => ({
        get: jest.fn().mockResolvedValue(entriesSnapshot),
      })),
    } as unknown as BusinessStoreService;
    const service = new ReceivablesService(store);

    await expect(service.dashboard('business-1')).resolves.toEqual({
      outstandingTotal: 110,
      overdueTotal: 70,
      customerCount: 2,
    });
  });

  it('records a partial payment as a negative ledger amount', async () => {
    const set = jest.fn().mockResolvedValue(undefined);
    const add = jest.fn().mockResolvedValue(undefined);
    const store = {
      collection: jest.fn((_businessId: string, name: string) => {
        if (name === 'contacts') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue({ exists: true }),
            })),
          };
        }
        if (name === 'receivableEntries') {
          return {
            doc: jest.fn(() => ({ id: 'payment-1', set })),
          };
        }
        return { add };
      }),
    } as unknown as BusinessStoreService;
    const service = new ReceivablesService(store);

    await expect(
      service.recordPayment('business-1', 'actor-1', 'contact-1', {
        amount: 40.25,
        paidAt: '2026-08-01T00:00:00.000Z',
      }),
    ).resolves.toEqual({ id: 'payment-1', type: 'payment' });
    expect(set).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'payment',
        contactId: 'contact-1',
        signedAmount: -40.25,
        paidAt: '2026-08-01T00:00:00.000Z',
        createdBy: 'actor-1',
      }),
    );
    expect(add).toHaveBeenCalledWith(
      expect.objectContaining({
        actorId: 'actor-1',
        action: 'payment.recorded',
        resourceId: 'payment-1',
      }),
    );
  });

  it('writes a Firestore-safe invoice document when optional fields are omitted', async () => {
    // Exactly what the mobile app posts: invoiceNumber and dueDate left out.
    // ValidationPipe({ transform: true }) turns this into class instances, so
    // build the DTO the same way instead of using a plain object literal.
    const dto = plainToInstance(ApproveInvoiceDto, {
      extractionId: 'extraction-1',
      contactId: 'contact-1',
      invoiceDate: '2026-08-12',
      total: 1500,
      items: [
        { name: 'Atta 20kg', quantity: 2, unitPrice: 750, lineTotal: 1500 },
      ],
    });

    const writes: Record<string, unknown>[] = [];
    const transaction = {
      get: jest.fn((ref: { __kind: string }) =>
        Promise.resolve(
          ref.__kind === 'extraction'
            ? { exists: true, data: () => ({ status: 'needs_review' }) }
            : { exists: true, data: () => ({ name: 'Bolan Kiryana' }) },
        ),
      ),
      set: jest.fn((_ref: unknown, data: Record<string, unknown>) =>
        writes.push(data),
      ),
      update: jest.fn(),
    };
    const store = {
      collection: jest.fn((_businessId: string, name: string) => ({
        firestore: {
          runTransaction: (run: (t: typeof transaction) => Promise<void>) =>
            run(transaction),
        },
        doc: jest.fn((id?: string) => ({
          id: id ?? `${name}-generated`,
          __kind: name === 'invoiceExtractions' ? 'extraction' : name,
        })),
        add: jest.fn().mockResolvedValue(undefined),
      })),
    } as unknown as BusinessStoreService;

    await expect(
      service(store).approveInvoice('business-1', 'actor-1', dto),
    ).resolves.toEqual({ id: 'invoices-generated', status: 'approved' });

    const [invoice, entry] = writes;
    expect(invoice).toMatchObject({
      extractionId: 'extraction-1',
      contactId: 'contact-1',
      invoiceNumber: null,
      dueDate: null,
      total: 1500,
      status: 'approved',
      approvedBy: 'actor-1',
    });
    expect(entry).toMatchObject({ type: 'invoice', signedAmount: 1500 });

    // Firestore rejects undefined values and objects with custom prototypes.
    // Both used to reach it here and turned every approval into a 500.
    expectFirestoreSafe(invoice, 'invoice');
    expectFirestoreSafe(entry, 'receivableEntry');
    expect(Object.getPrototypeOf((invoice.items as unknown[])[0])).toBe(
      Object.prototype,
    );
  });
});

function service(store: BusinessStoreService): ReceivablesService {
  return new ReceivablesService(store);
}

/** Fails if `value` holds anything the Firestore serializer would reject. */
function expectFirestoreSafe(value: unknown, path: string): void {
  if (value === undefined) {
    throw new Error(`undefined is not a valid Firestore value at "${path}"`);
  }
  if (value === null || typeof value !== 'object') return;
  if (value instanceof FieldValue || value instanceof Date) return;
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      expectFirestoreSafe(item, `${path}.${index}`),
    );
    return;
  }
  if (Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(
      `object with a custom prototype (${value.constructor.name}) at "${path}"`,
    );
  }
  for (const [key, child] of Object.entries(value)) {
    expectFirestoreSafe(child, `${path}.${key}`);
  }
}

function ledgerDoc(
  id: string,
  type: 'invoice' | 'payment',
  contactId: string,
  signedAmount: number,
  dueDate?: string,
) {
  return {
    id,
    data: () => ({ type, contactId, signedAmount, dueDate }),
  };
}
