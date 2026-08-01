class LedgerEntry {
  const LedgerEntry({
    required this.type,
    required this.signedAmount,
    this.occurredAt,
    this.note,
    this.createdAt,
  });

  final String type;
  final double signedAmount;
  final DateTime? occurredAt;
  final String? note;
  final DateTime? createdAt;

  bool get isInvoice => type == 'invoice';

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      type: json['type']?.toString() ?? '',
      signedAmount: (json['signedAmount'] as num?)?.toDouble() ?? 0,
      occurredAt: _parseDateTime(json['occurredAt']),
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
