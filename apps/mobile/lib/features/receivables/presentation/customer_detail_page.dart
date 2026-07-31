import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/amount_text.dart';
import '../domain/ledger_entry.dart';
import '../domain/receivable.dart';
import 'receivables_controller.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(receivablesProvider).asData?.value ?? const <Customer>[];
    final customer = customers.where((c) => c.id == customerId).firstOrNull;

    if (customer == null) {
      return const Scaffold(body: Center(child: Text('Customer not found')));
    }

    final ledgerAsync = ref.watch(ledgerProvider(customerId));

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.mint,
            child: Text(customer.name.characters.first, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.brand)),
          ),
          const SizedBox(height: 14),
          Text(customer.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(customer.phone, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total outstanding', style: TextStyle(color: Color(0xFFBBD2C4))),
                const SizedBox(height: 8),
                AmountText(customer.balance, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(customer.isOverdue ? 'Payment is overdue' : 'Due in a few days', style: TextStyle(color: customer.isOverdue ? const Color(0xFFFFB4AB) : const Color(0xFFBBD2C4))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () => context.push('/payment/${customer.id}'), icon: const Icon(Icons.payments_outlined), label: const Text('Record payment')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder draft ready for WhatsApp'))), icon: const Icon(Icons.chat_bubble_outline_rounded), label: const Text('Send WhatsApp reminder')),
          const SizedBox(height: 28),
          Text('Invoices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ledgerAsync.when(
            data: (entries) {
              final invoices = entries.where((entry) => entry.isInvoice).toList()
                ..sort((a, b) => (b.occurredAt ?? b.createdAt ?? DateTime(0))
                    .compareTo(a.occurredAt ?? a.createdAt ?? DateTime(0)));

              if (invoices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No invoices recorded yet.', style: TextStyle(color: AppColors.muted)),
                );
              }

              return Column(
                children: [
                  for (final invoice in invoices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InvoiceLedgerCard(invoice: invoice),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Expanded(child: Text('Unable to load invoices.', style: TextStyle(color: AppColors.danger))),
                  TextButton(
                    onPressed: () => ref.invalidate(ledgerProvider(customerId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLedgerCard extends StatelessWidget {
  const _InvoiceLedgerCard({required this.invoice});

  final LedgerEntry invoice;

  @override
  Widget build(BuildContext context) {
    final date = invoice.occurredAt;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(invoice.note?.isNotEmpty == true ? invoice.note! : 'Invoice'),
        subtitle: Text(date != null ? _formatDate(date) : 'Date unavailable'),
        trailing: AmountText(invoice.signedAmount, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
