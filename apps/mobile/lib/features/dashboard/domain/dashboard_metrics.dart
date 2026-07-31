class DashboardMetrics {
  const DashboardMetrics({
    required this.outstandingTotal,
    required this.overdueTotal,
    required this.customerCount,
  });

  final double outstandingTotal;
  final double overdueTotal;
  final int customerCount;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      outstandingTotal: (json['outstandingTotal'] as num?)?.toDouble() ?? 0,
      overdueTotal: (json['overdueTotal'] as num?)?.toDouble() ?? 0,
      customerCount: (json['customerCount'] as num?)?.toInt() ?? 0,
    );
  }
}
