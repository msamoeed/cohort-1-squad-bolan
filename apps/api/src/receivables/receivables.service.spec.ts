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
});

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
