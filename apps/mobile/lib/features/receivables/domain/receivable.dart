class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
    required this.invoiceCount,
    required this.isOverdue,
  });

  final String id;
  final String name;
  final String phone;
  final double balance;
  final int invoiceCount;
  final bool isOverdue;
}
