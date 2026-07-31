import {
  summarizeContactReceivables,
  summarizeReceivablesByContact,
} from './receivable-calculations';

describe('receivable calculations', () => {
  const now = new Date('2026-08-01T00:00:00.000Z');

  it('applies a partial payment to the oldest due invoice', () => {
    const summary = summarizeContactReceivables(
      [
        {
          id: 'invoice-1',
          type: 'invoice',
          contactId: 'contact-1',
          signedAmount: 100,
          dueDate: '2026-07-01T00:00:00.000Z',
        },
        {
          id: 'payment-1',
          type: 'payment',
          contactId: 'contact-1',
          signedAmount: -40,
        },
      ],
      now,
    );

    expect(summary).toEqual({
      currentBalance: 60,
      invoiceCount: 1,
      earliestDueDate: '2026-07-01T00:00:00.000Z',
      overdue: true,
      overdueBalance: 60,
    });
  });

  it('clears overdue debt before applying payment to a future invoice', () => {
    const summary = summarizeContactReceivables(
      [
        {
          id: 'invoice-overdue',
          type: 'invoice',
          contactId: 'contact-1',
          signedAmount: 100,
          dueDate: '2026-07-01T00:00:00.000Z',
        },
        {
          id: 'invoice-future',
          type: 'invoice',
          contactId: 'contact-1',
          signedAmount: 50,
          dueDate: '2026-08-10T00:00:00.000Z',
        },
        {
          id: 'payment-1',
          type: 'payment',
          contactId: 'contact-1',
          signedAmount: -120,
        },
      ],
      now,
    );

    expect(summary).toEqual({
      currentBalance: 30,
      invoiceCount: 2,
      earliestDueDate: '2026-08-10T00:00:00.000Z',
      overdue: false,
      overdueBalance: 0,
    });
  });

  it('keeps each contact calculation isolated', () => {
    const summaries = summarizeReceivablesByContact(
      [
        {
          type: 'invoice',
          contactId: 'contact-1',
          signedAmount: 75.25,
          dueDate: '2026-07-01T00:00:00.000Z',
        },
        {
          type: 'payment',
          contactId: 'contact-1',
          signedAmount: -25.1,
        },
        {
          type: 'invoice',
          contactId: 'contact-2',
          signedAmount: 20,
          dueDate: '2026-08-10T00:00:00.000Z',
        },
      ],
      now,
    );

    expect(summaries.get('contact-1')?.currentBalance).toBe(50.15);
    expect(summaries.get('contact-1')?.overdueBalance).toBe(50.15);
    expect(summaries.get('contact-2')?.currentBalance).toBe(20);
    expect(summaries.get('contact-2')?.overdue).toBe(false);
  });
});
