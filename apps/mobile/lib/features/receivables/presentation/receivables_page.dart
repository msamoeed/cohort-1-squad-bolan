import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/amount_text.dart';
import '../domain/receivable.dart';
import 'receivables_controller.dart';

class ReceivablesPage extends ConsumerWidget {
  const ReceivablesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCustomers = ref.watch(receivablesProvider);

    final children = <Widget>[
      Text(
        'Receivables',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Keep every outstanding payment in one place.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      const TextField(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          hintText: 'Search customers',
        ),
      ),
      const SizedBox(height: 20),
    ];

    children.addAll(asyncCustomers.when(
      data: (customers) => [
        for (final customer in customers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CustomerReceivableCard(customer: customer),
          ),
      ],
      loading: () => const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
      error: (error, stackTrace) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ),
        ),
      ],
    ));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
        children: children,
      ),
    );
  }
}

class _CustomerReceivableCard extends StatelessWidget {
  const _CustomerReceivableCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final isOverdue = customer.isOverdue;

    return Card(
      child: ListTile(
        onTap: () => context.push('/customer/${customer.id}'),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor:
              isOverdue ? const Color(0xFFFFE7E4) : AppColors.mint,
          child: Icon(
            Icons.store_rounded,
            color: isOverdue ? AppColors.danger : AppColors.brand,
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${customer.invoiceCount} invoice${customer.invoiceCount == 1 ? '' : 's'} · ${isOverdue ? 'Overdue' : 'Due soon'}',
          style: TextStyle(
            color: isOverdue ? AppColors.danger : AppColors.muted,
          ),
        ),
        trailing: AmountText(
          customer.balance,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
