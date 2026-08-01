import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../reminders/domain/reminder_draft.dart';
import '../../reminders/presentation/reminder_providers.dart';
import '../domain/ledger_entry.dart';
import '../domain/receivable.dart';
import 'receivables_controller.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({required this.customerId, super.key});

  final String customerId;

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  bool _isRequestingReminder = false;

  @override
  Widget build(BuildContext context) {
    final customers =
        ref.watch(receivablesProvider).asData?.value ?? const <Customer>[];
    final customer = customers
        .where((c) => c.id == widget.customerId)
        .firstOrNull;

    if (customer == null) {
      return const Scaffold(body: Center(child: Text('Customer not found')));
    }

    final ledgerAsync = ref.watch(ledgerProvider(widget.customerId));

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.mint,
            child: Text(
              customer.name.characters.first,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            customer.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(customer.phone, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total outstanding',
                  style: TextStyle(color: Color(0xFFBBD2C4)),
                ),
                const SizedBox(height: 8),
                AmountText(
                  customer.balance,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.isOverdue
                      ? 'Payment is overdue'
                      : 'Due in a few days',
                  style: TextStyle(
                    color: customer.isOverdue
                        ? const Color(0xFFFFB4AB)
                        : const Color(0xFFBBD2C4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.push('/payment/${customer.id}'),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record payment'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isRequestingReminder
                ? null
                : () => _requestReminderDraft(customer),
            icon: _isRequestingReminder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline_rounded),
            label: Text(
              _isRequestingReminder
                  ? 'Preparing reminder…'
                  : 'Draft WhatsApp reminder',
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Invoices',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ledgerAsync.when(
            data: (entries) {
              final invoices =
                  entries.where((entry) => entry.isInvoice).toList()..sort(
                    (a, b) => (b.occurredAt ?? b.createdAt ?? DateTime(0))
                        .compareTo(a.occurredAt ?? a.createdAt ?? DateTime(0)),
                  );

              if (invoices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No invoices recorded yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
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
                  const Expanded(
                    child: Text(
                      'Unable to load invoices.',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(ledgerProvider(widget.customerId)),
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

  Future<void> _requestReminderDraft(Customer customer) async {
    if (_isRequestingReminder) return;

    final validationError = _validateReminderRequest(customer);
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _isRequestingReminder = true);

    try {
      final draft = await ref
          .read(remindersApiProvider)
          .createDraft(customer.id)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final confirmed = await _reviewDraft(draft);
      if (confirmed != true || !mounted) return;

      await _openWhatsApp(draft.whatsappUri);
    } catch (error) {
      if (mounted) {
        _showError(_reminderErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingReminder = false);
      }
    }
  }

  Future<void> _openWhatsApp(Uri whatsappUri) async {
    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showError(
          'Unable to open WhatsApp. Check that WhatsApp is installed and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showError(
          'Unable to open WhatsApp. Check that WhatsApp is installed and try again.',
        );
      }
    }
  }

  String? _validateReminderRequest(Customer customer) {
    if (customer.balance <= 0) {
      return 'This customer has no outstanding balance.';
    }

    final phone = customer.phone.trim();
    if (phone.isEmpty) {
      return 'Add a phone number for this customer before drafting a reminder.';
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 15 || digits.startsWith('0')) {
      return 'Enter a valid phone number with country code before drafting a reminder.';
    }
    return null;
  }

  Future<bool?> _reviewDraft(ReminderDraft draft) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review WhatsApp reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WhatsApp will open with this draft. You will still choose whether to send it.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(draft.message),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open WhatsApp'),
          ),
        ],
      ),
    );
  }

  String _reminderErrorMessage(Object error) {
    if (error is TimeoutException) {
      return 'The reminder request timed out. Please try again.';
    }
    if (error is FormatException) {
      return 'The server returned an invalid reminder draft. Please try again.';
    }
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'The reminder request timed out. Please try again.';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.response == null) {
        return 'Unable to reach the server. Check your connection and try again.';
      }

      final backendMessage = _readBackendMessage(error.response?.data);
      if (backendMessage != null) return backendMessage;
      if (error.response?.statusCode == 404) {
        return 'This customer could not be found.';
      }
    }
    return 'Unable to prepare the reminder. Please try again.';
  }

  String? _readBackendMessage(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    if (message is List && message.isNotEmpty) {
      return message.map((item) => item.toString()).join('\n');
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
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
        title: Text(
          invoice.note?.isNotEmpty == true ? invoice.note! : 'Invoice',
        ),
        subtitle: Text(date != null ? _formatDate(date) : 'Date unavailable'),
        trailing: AmountText(
          invoice.signedAmount,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
