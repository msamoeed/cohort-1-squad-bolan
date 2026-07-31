import { BusinessStoreService } from '../common/firebase/business-store.service';
import { ContactsService } from './contacts.service';

describe('ContactsService', () => {
  it('returns additive financial summaries for every contact', async () => {
    const contactsSnapshot = {
      docs: [
        {
          id: 'contact-1',
          data: () => ({
            name: 'Raza Store',
            phone: '+923001234567',
            whatsappOptIn: true,
            createdAt: '2026-07-01T00:00:00.000Z',
            updatedAt: '2026-07-02T00:00:00.000Z',
          }),
        },
        {
          id: 'contact-2',
          data: () => ({
            name: 'Noor General Store',
            phone: '+923009876543',
            email: 'owner@example.com',
          }),
        },
      ],
    };
    const entriesSnapshot = {
      docs: [
        {
          id: 'invoice-1',
          data: () => ({
            type: 'invoice',
            contactId: 'contact-1',
            signedAmount: 100,
            dueDate: '2020-01-01T00:00:00.000Z',
          }),
        },
        {
          id: 'payment-1',
          data: () => ({
            type: 'payment',
            contactId: 'contact-1',
            signedAmount: -25,
          }),
        },
      ],
    };
    const store = {
      collection: jest.fn((_businessId: string, name: string) => {
        if (name === 'contacts') {
          return {
            orderBy: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(contactsSnapshot),
            })),
          };
        }
        return {
          get: jest.fn().mockResolvedValue(entriesSnapshot),
        };
      }),
    } as unknown as BusinessStoreService;
    const service = new ContactsService(store);

    await expect(service.list('business-1')).resolves.toEqual([
      {
        id: 'contact-1',
        name: 'Raza Store',
        phone: '+923001234567',
        email: null,
        whatsappOptIn: true,
        createdAt: '2026-07-01T00:00:00.000Z',
        updatedAt: '2026-07-02T00:00:00.000Z',
        currentBalance: 75,
        invoiceCount: 1,
        earliestDueDate: '2020-01-01T00:00:00.000Z',
        overdue: true,
      },
      {
        id: 'contact-2',
        name: 'Noor General Store',
        phone: '+923009876543',
        email: 'owner@example.com',
        whatsappOptIn: false,
        createdAt: null,
        updatedAt: null,
        currentBalance: 0,
        invoiceCount: 0,
        earliestDueDate: null,
        overdue: false,
      },
    ]);
  });
});
