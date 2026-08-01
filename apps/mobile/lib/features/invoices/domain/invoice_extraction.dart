class InvoiceExtraction {
  const InvoiceExtraction({
    required this.status,
    this.draft,
    this.failureReason,
  });

  final String status;
  final InvoiceDraft? draft;
  final String? failureReason;

  bool get isApproved => status == 'approved';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';

  factory InvoiceExtraction.fromJson(Map<String, dynamic> json) {
    final draftJson = json['draft'];
    return InvoiceExtraction(
      status: json['status']?.toString() ?? '',
      draft: draftJson is Map<String, dynamic>
          ? InvoiceDraft.fromJson(draftJson)
          : null,
      failureReason: json['failureReason']?.toString(),
    );
  }
}

class InvoiceDraft {
  const InvoiceDraft({
    this.invoiceNumber,
    this.invoiceDate,
    this.dueDate,
    this.customerName,
    this.total,
    required this.items,
  });

  final String? invoiceNumber;
  final String? invoiceDate;
  final String? dueDate;
  final String? customerName;
  final double? total;
  final List<InvoiceDraftItem> items;

  factory InvoiceDraft.fromJson(Map<String, dynamic> json) {
    return InvoiceDraft(
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDate: json['invoiceDate']?.toString(),
      dueDate: json['dueDate']?.toString(),
      customerName: json['customerName']?.toString(),
      total: (json['total'] as num?)?.toDouble(),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceDraftItem.fromJson)
          .toList(),
    );
  }
}

class InvoiceDraftItem {
  const InvoiceDraftItem({
    this.ocrText,
    this.normalizedProduct,
    this.quantity,
    this.unitPrice,
    this.lineTotal,
    this.confidence,
    this.crossedOut = false,
  });

  final String? ocrText;
  final String? normalizedProduct;
  final double? quantity;
  final double? unitPrice;
  final double? lineTotal;
  final String? confidence;
  final bool crossedOut;

  String get displayName => normalizedProduct?.trim().isNotEmpty == true
      ? normalizedProduct!.trim()
      : (ocrText?.trim() ?? '');

  factory InvoiceDraftItem.fromJson(Map<String, dynamic> json) {
    return InvoiceDraftItem(
      ocrText: json['ocrText']?.toString(),
      normalizedProduct: json['normalizedProduct']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      lineTotal: (json['lineTotal'] as num?)?.toDouble(),
      confidence: json['confidence']?.toString(),
      crossedOut: json['crossedOut'] as bool? ?? false,
    );
  }
}

class InvoiceApprovalItem {
  const InvoiceApprovalItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineTotal': lineTotal,
  };
}
