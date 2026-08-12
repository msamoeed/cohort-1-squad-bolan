import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../receivables/domain/receivable.dart';
import '../../receivables/presentation/receivables_controller.dart';
import '../domain/invoice_extraction.dart';
import 'invoice_providers.dart';

class InvoiceReviewPage extends ConsumerStatefulWidget {
  const InvoiceReviewPage({
    required this.extractionId,
    this.imagePath,
    super.key,
  });

  final String extractionId;
  final String? imagePath;

  @override
  ConsumerState<InvoiceReviewPage> createState() => _InvoiceReviewPageState();
}

class _InvoiceReviewPageState extends ConsumerState<InvoiceReviewPage> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _totalController = TextEditingController();

  DateTime? _invoiceDate;
  DateTime? _dueDate;
  String? _selectedContactId;
  String? _draftCustomerName;
  List<_ItemEditor> _items = [];
  List<String> _validationErrors = const [];

  bool _seeded = false;
  bool _autoSelectAttempted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _totalController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extractionAsync = ref.watch(
      invoiceExtractionProvider(widget.extractionId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Review invoice')),
      body: SafeArea(
        child: extractionAsync.when(
          data: _buildBody,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _buildLoadError(error),
        ),
      ),
    );
  }

  Widget _buildBody(InvoiceExtraction extraction) {
    if (extraction.isFailed) return _buildFailedState(extraction);
    if (extraction.isApproved) return _buildApprovedState();
    if (extraction.isProcessing || extraction.draft == null) {
      return _buildProcessingState();
    }

    // Seeding runs once per extraction load; later rebuilds (e.g. the
    // contact list resolving) must not clobber the shopkeeper's edits.
    if (!_seeded) {
      _seedFromExtraction(extraction);
    }

    return _buildForm(extraction);
  }

  void _seedFromExtraction(InvoiceExtraction extraction) {
    final draft = extraction.draft!;
    _invoiceNumberController.text = draft.invoiceNumber ?? '';
    _totalController.text = _formatNumber(draft.total, _moneyDecimals);
    _invoiceDate = _tryParseDate(draft.invoiceDate) ?? DateTime.now();
    _dueDate = _tryParseDate(draft.dueDate);
    _draftCustomerName = draft.customerName;
    _items = draft.items.isEmpty
        ? [_ItemEditor()]
        : draft.items
              .map(
                (item) => _ItemEditor(
                  name: item.displayName,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  lineTotal: item.lineTotal,
                  confidence: item.confidence,
                  crossedOut: item.crossedOut,
                  ocrText: item.ocrText,
                ),
              )
              .toList();
    _seeded = true;
  }

  void _maybeAutoSelectContact(List<Customer> contacts) {
    if (_autoSelectAttempted || contacts.isEmpty) return;
    _autoSelectAttempted = true;
    final name = _draftCustomerName?.trim().toLowerCase();
    if (name == null || name.isEmpty) return;
    final match = contacts
        .where((c) => c.name.trim().toLowerCase() == name)
        .firstOrNull;
    if (match != null) _selectedContactId = match.id;
  }

  Widget _buildForm(InvoiceExtraction extraction) {
    final contactsAsync = ref.watch(receivablesProvider);
    contactsAsync.whenData(_maybeAutoSelectContact);
    final sectionTitle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInvoiceImage(),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.brand),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI extracted these details. Review and correct anything before approving.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Shop', style: sectionTitle),
          if (_draftCustomerName != null &&
              _draftCustomerName!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'OCR detected: "$_draftCustomerName"',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          else
            const SizedBox(height: 8),
          contactsAsync.when(
            data: (contacts) => contacts.isEmpty
                ? _buildNoContacts()
                : DropdownButtonFormField<String>(
              initialValue: _selectedContactId,
              decoration: const InputDecoration(labelText: 'Select customer'),
              items: [
                for (final contact in contacts)
                  DropdownMenuItem(
                    value: contact.id,
                    child: Text(contact.name),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedContactId = value),
              validator: (value) => value == null || value.isEmpty
                  ? 'Select the customer for this invoice.'
                  : null,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (error, stackTrace) => Row(
              children: [
                const Expanded(
                  child: Text(
                    'Unable to load customers.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(receivablesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Invoice details', style: sectionTitle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _invoiceNumberController,
            decoration: const InputDecoration(
              labelText: 'Invoice number (optional)',
            ),
          ),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Invoice date',
            value: _invoiceDate,
            onTap: _pickInvoiceDate,
          ),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Due date (optional)',
            value: _dueDate,
            onTap: _pickDueDate,
            onClear: _dueDate != null
                ? () => setState(() => _dueDate = null)
                : null,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items', style: sectionTitle),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add item'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildItemCard(i),
            ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _totalController,
            decoration: const InputDecoration(
              labelText: 'Invoice total',
              prefixText: 'Rs  ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final parsed = _parseMoney(value);
              if (parsed == null || parsed <= 0) {
                return _decimalPlacesOf(value) > _moneyDecimals
                    ? 'Use at most $_moneyDecimals decimal places.'
                    : 'Enter a valid invoice total.';
              }
              return null;
            },
          ),
          if (_validationErrors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEAE8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final error in _validationErrors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          error,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _approve,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Approve invoice & create receivable'),
          ),
        ],
      ),
    );
  }

  /// With no contacts the dropdown renders empty and the invoice can never be
  /// approved, so offer the way out instead of a dead control.
  Widget _buildNoContacts() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3E7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You have no customers yet. Add the shop this invoice belongs to, '
            'then come back to approve it.',
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/customers/new'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(
              _draftCustomerName != null &&
                      _draftCustomerName!.trim().isNotEmpty
                  ? 'Add "${_draftCustomerName!.trim()}"'
                  : 'Add customer',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceImage() {
    final imagePath = widget.imagePath;
    if (imagePath == null || imagePath.isEmpty) {
      return const _InvoiceImageError();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 220,
        color: const Color(0xFFE9E9E4),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const _InvoiceImageError();
          },
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.nameController,
                    decoration: const InputDecoration(labelText: 'Item name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Remove item',
                  onPressed: _items.length > 1
                      ? () => _removeItem(index)
                      : null,
                ),
              ],
            ),
            if (item.confidence != null || item.crossedOut)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (item.confidence != null)
                      _ConfidenceBadge(confidence: item.confidence!),
                    if (item.crossedOut) const _CrossedOutBadge(),
                  ],
                ),
              ),
            if (item.crossedOut && (item.ocrText?.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'OCR text: ${item.ocrText}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantityController,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _quantityValidator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.unitPriceController,
                    decoration: const InputDecoration(labelText: 'Unit price'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _moneyValidator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.lineTotalController,
                    decoration: const InputDecoration(labelText: 'Line total'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _moneyValidator,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value != null ? _formatDate(value) : 'Not set',
          style: TextStyle(
            color: value != null ? AppColors.ink : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildFailedState(InvoiceExtraction extraction) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            const Text(
              'Invoice extraction failed',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              extraction.failureReason ??
                  'The OCR service could not read this invoice.',
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/upload'),
              child: const Text('Try uploading again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Still reading your invoice…',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.invalidate(
                invoiceExtractionProvider(widget.extractionId),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 48,
              color: AppColors.brand,
            ),
            const SizedBox(height: 12),
            const Text(
              'This invoice has already been approved.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/receivables'),
              child: const Text('Go to receivables'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(Object error) {
    final isNotFound =
        error is DioException && error.response?.statusCode == 404;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              isNotFound
                  ? 'This invoice extraction could not be found. It may have expired.'
                  : 'Unable to load this invoice. Check your connection and try again.',
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/upload'),
                  child: const Text('Back to upload'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(
                    invoiceExtractionProvider(widget.extractionId),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addItem() => setState(() => _items.add(_ItemEditor()));

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickInvoiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _invoiceDate ?? DateTime.now(),
      firstDate: _invoiceDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _approve() async {
    if (_isSubmitting) return;

    final formValid = _formKey.currentState?.validate() ?? false;
    final errors = <String>[];

    if (_selectedContactId == null || _selectedContactId!.isEmpty) {
      errors.add('Select the customer for this invoice.');
    }
    if (_invoiceDate == null) {
      errors.add('Select the invoice date.');
    }
    if (_items.isEmpty) {
      errors.add('Add at least one invoice item.');
    }

    final total = _parseMoney(_totalController.text);
    if (total == null || total <= 0) {
      errors.add(
        'Enter a valid invoice total using at most $_moneyDecimals decimal places.',
      );
    }

    final approvalItems = <InvoiceApprovalItem>[];
    var itemsSum = 0.0;
    for (final item in _items) {
      final name = item.nameController.text.trim();
      // These parsers enforce the API's precision limits, so an OCR value like
      // 77.451 is caught here instead of coming back as a 400.
      final quantity = _parseQuantity(item.quantityController.text);
      final unitPrice = _parseMoney(item.unitPriceController.text);
      final lineTotal = _parseMoney(item.lineTotalController.text);

      final isValid =
          name.isNotEmpty &&
          quantity != null &&
          unitPrice != null &&
          lineTotal != null;

      if (!isValid) {
        final label = name.isEmpty ? 'unnamed item' : name;
        errors.add(
          _hasTooManyDecimals(item)
              ? 'Round the amounts for "$label" to at most $_moneyDecimals decimal places '
                    '(quantity allows $_quantityDecimals).'
              : 'Fix the invalid values for "$label".',
        );
        continue;
      }

      approvalItems.add(
        InvoiceApprovalItem(
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
        ),
      );
      itemsSum += lineTotal;
    }

    if (total != null &&
        approvalItems.isNotEmpty &&
        (total - itemsSum).abs() > 1) {
      errors.add(
        'Item totals (Rs ${itemsSum.toStringAsFixed(0)}) do not match the invoice total (Rs ${total.toStringAsFixed(0)}).',
      );
    }

    if (!formValid || errors.isNotEmpty) {
      // A failing field validator with no matching entry in `errors` (an empty
      // invoice total, say) used to clear the summary and show nothing at all,
      // so the button looked dead. Always leave the shopkeeper with a reason.
      setState(() {
        _validationErrors = errors.isEmpty
            ? const ['Fix the highlighted fields before approving.']
            : errors;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationErrors = const [];
    });

    try {
      await ref
          .read(invoiceApiProvider)
          .approveInvoice(
            extractionId: widget.extractionId,
            contactId: _selectedContactId!,
            invoiceNumber: _invoiceNumberController.text.trim().isEmpty
                ? null
                : _invoiceNumberController.text.trim(),
            invoiceDate: _isoDate(_invoiceDate!),
            dueDate: _dueDate == null ? null : _isoDate(_dueDate!),
            total: total!,
            items: approvalItems,
          );

      ref.invalidate(invoiceExtractionProvider(widget.extractionId));
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(receivablesProvider);
      ref.invalidate(ledgerProvider(_selectedContactId!));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Invoice approved and added to receivables.'),
        ),
      );
      context.go('/receivables');
    } on DioException catch (error) {
      _handleApprovalError(error);
    } catch (_) {
      _showApprovalError('Unable to approve the invoice. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleApprovalError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String message;

    if (status != null && status >= 500) {
      // Nest reports every unhandled failure as a bare "Internal server
      // error", which tells the shopkeeper nothing. Say where to look instead.
      message =
          'The server could not save this invoice (error $status). '
          'Your edits are still here — try again, and check the API logs if it keeps failing.';
    } else if (data is Map<String, dynamic> && data['message'] != null) {
      final raw = data['message'];
      message = raw is List ? raw.join('\n') : raw.toString();
    } else if (status == 404) {
      message =
          'This invoice extraction or customer could not be found. It may have expired.';
    } else if (status == 409) {
      message = 'This invoice has already been approved.';
      ref.invalidate(invoiceExtractionProvider(widget.extractionId));
    } else if (_isNetworkError(error.type)) {
      message =
          'Unable to reach the server. Check your connection and try again.';
    } else {
      message = 'Unable to approve the invoice. Please try again.';
    }

    _showApprovalError(message);
  }

  /// Surfaces a submission failure twice: in the summary box above the button
  /// and as a snack bar, because the box sits mid-list and is easy to miss.
  void _showApprovalError(String message) {
    if (!mounted) return;
    setState(() => _validationErrors = [message]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
        content: Text(message),
      ),
    );
  }

  bool _isNetworkError(DioExceptionType type) {
    return type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout;
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

  String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  bool _hasTooManyDecimals(_ItemEditor item) {
    return _decimalPlacesOf(item.quantityController.text) > _quantityDecimals ||
        _decimalPlacesOf(item.unitPriceController.text) > _moneyDecimals ||
        _decimalPlacesOf(item.lineTotalController.text) > _moneyDecimals;
  }

  String? _quantityValidator(String? value) {
    if (_parseQuantity(value) != null) return null;
    return _decimalPlacesOf(value) > _quantityDecimals
        ? 'Max $_quantityDecimals dp'
        : 'Invalid';
  }

  String? _moneyValidator(String? value) {
    if (_parseMoney(value) != null) return null;
    return _decimalPlacesOf(value) > _moneyDecimals
        ? 'Max $_moneyDecimals dp'
        : 'Invalid';
  }
}

// The API caps money at 2 decimal places and quantities at 3 (InvoiceItemDto
// in apps/api/src/common/dto/api.dto.ts). Gemini regularly returns unit prices
// like 77.451, so the form works in the same precision the API accepts —
// otherwise every OCR'd invoice round-trips into a 400.
const _moneyDecimals = 2;
const _quantityDecimals = 3;

/// Rounds to [decimals] and drops trailing zeros: 77.451 -> "77.45", 28 -> "28".
String _formatNumber(double? value, int decimals) {
  if (value == null) return '';
  var text = value.toStringAsFixed(decimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

int _decimalPlacesOf(String? value) {
  final text = (value ?? '').trim();
  final dot = text.indexOf('.');
  return dot < 0 ? 0 : text.length - dot - 1;
}

/// Non-negative and within the API's money precision, else null.
double? _parseMoney(String? value) {
  final text = (value ?? '').trim();
  final parsed = double.tryParse(text);
  if (parsed == null || parsed < 0) return null;
  return _decimalPlacesOf(text) > _moneyDecimals ? null : parsed;
}

/// Positive and within the API's quantity precision, else null.
double? _parseQuantity(String? value) {
  final text = (value ?? '').trim();
  final parsed = double.tryParse(text);
  if (parsed == null || parsed <= 0) return null;
  return _decimalPlacesOf(text) > _quantityDecimals ? null : parsed;
}

class _InvoiceImageError extends StatelessWidget {
  const _InvoiceImageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E9E4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Unable to display the uploaded invoice image.',
        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ItemEditor {
  _ItemEditor({
    String? name,
    double? quantity,
    double? unitPrice,
    double? lineTotal,
    this.confidence,
    this.crossedOut = false,
    this.ocrText,
  }) : nameController = TextEditingController(text: name ?? ''),
       // Seeded at the precision the API accepts, so what the shopkeeper
       // reviews on screen is exactly what gets posted.
       quantityController = TextEditingController(
         text: _formatNumber(quantity, _quantityDecimals),
       ),
       unitPriceController = TextEditingController(
         text: _formatNumber(unitPrice, _moneyDecimals),
       ),
       lineTotalController = TextEditingController(
         text: _formatNumber(lineTotal, _moneyDecimals),
       );

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController lineTotalController;
  final String? confidence;
  final bool crossedOut;
  final String? ocrText;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    lineTotalController.dispose();
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final String confidence;

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'high' => AppColors.brand,
      'medium' => AppColors.warning,
      'low' => AppColors.danger,
      _ => AppColors.muted,
    };
    final label = confidence.isEmpty
        ? confidence
        : '${confidence[0].toUpperCase()}${confidence.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label confidence',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CrossedOutBadge extends StatelessWidget {
  const _CrossedOutBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Crossed out on invoice',
        style: TextStyle(
          color: AppColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
