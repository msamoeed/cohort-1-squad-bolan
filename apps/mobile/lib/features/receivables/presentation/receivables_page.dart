import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/amount_text.dart';
import '../domain/receivable.dart';
import 'receivables_controller.dart';

class ReceivablesPage extends ConsumerStatefulWidget {
  const ReceivablesPage({super.key});

  @override
  ConsumerState<ReceivablesPage> createState() => _ReceivablesPageState();
}

class _ReceivablesPageState extends ConsumerState<ReceivablesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncCustomers = ref.watch(receivablesProvider);

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              'Receivables',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => context.push('/customers/new'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Add customer',
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Keep every outstanding payment in one place.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Search customers',
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
      const SizedBox(height: 20),
    ];

    children.addAll(asyncCustomers.when(
      data: (customers) {
        if (customers.isEmpty) return [const _NoCustomersYet()];

        final matches = _filter(customers);
        if (matches.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'No customer matches "$_query".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ];
        }

        return [
          for (final customer in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CustomerReceivableCard(customer: customer),
            ),
        ];
      },
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unable to load customers.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => ref.invalidate(receivablesProvider),
                      child: const Text('Retry'),
                    ),
                  ),
                ],
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

  List<Customer> _filter(List<Customer> customers) {
    if (_query.isEmpty) return customers;
    final needle = _query.toLowerCase();
    return customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(needle) ||
              customer.phone.replaceAll(' ', '').contains(needle),
        )
        .toList(growable: false);
  }
}

class _NoCustomersYet extends StatelessWidget {
  const _NoCustomersYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.mint,
            child: Icon(
              Icons.store_rounded,
              size: 32,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No customers yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add the shops you supply on credit. You need at least one before '
            'you can approve an invoice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/customers/new'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add your first customer'),
          ),
        ],
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
