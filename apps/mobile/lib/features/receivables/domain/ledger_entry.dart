class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.contactId,
    required this.signedAmount,
    this.invoiceId,
    this.occurredAt,
    this.dueDate,
    this.paidAt,
    this.note,
    this.createdAt,
  });

  final String id;
  final String type;
  final String contactId;
  final double signedAmount;
  final String? invoiceId;
  final DateTime? occurredAt;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? note;
  final DateTime? createdAt;

  bool get isInvoice => type == 'invoice';
  bool get isPayment => type == 'payment';

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      contactId: json['contactId']?.toString() ?? '',
      signedAmount: (json['signedAmount'] as num?)?.toDouble() ?? 0,
      invoiceId: json['invoiceId']?.toString(),
      occurredAt: _parseDateTime(json['occurredAt']),
      dueDate: _parseDateTime(json['dueDate']),
      paidAt: _parseDateTime(json['paidAt']),
      note: json['note']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
