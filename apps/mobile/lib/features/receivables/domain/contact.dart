class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.currentBalance = 0,
    this.invoiceCount = 0,
    this.overdue = false,
  });

  final String id;
  final String name;
  final String phone;
  final double currentBalance;
  final int invoiceCount;
  final bool overdue;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
      overdue: json['overdue'] as bool? ?? false,
    );
  }
}
