class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.whatsappOptIn,
    this.createdAt,
    this.updatedAt,
    this.currentBalance = 0,
    this.invoiceCount = 0,
    this.earliestDueDate,
    this.overdue = false,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool? whatsappOptIn;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double currentBalance;
  final int invoiceCount;
  final DateTime? earliestDueDate;
  final bool overdue;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      whatsappOptIn: json['whatsappOptIn'] as bool?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
      earliestDueDate: _parseDateTime(json['earliestDueDate']),
      overdue: json['overdue'] as bool? ?? false,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map<String, dynamic>) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'];
      if (seconds != null) {
        final millis = (seconds as num).toInt() * 1000;
        final fraction = (nanoseconds as num?)?.toInt() ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(millis + (fraction / 1e6).round());
      }
    }
    return null;
  }
}
