class ServiceCount {
  const ServiceCount({required this.nameAr, required this.count});

  final String nameAr;
  final int count;

  factory ServiceCount.fromJson(Map<String, dynamic> json) =>
      ServiceCount(nameAr: json['name_ar'] as String, count: json['count'] as int);
}

/// Result of the `barber_stats` RPC. Income counts completed bookings only.
class BarberStats {
  const BarberStats({
    required this.todayCustomers,
    required this.todayCompleted,
    required this.todayNoShow,
    required this.todayIncome,
    required this.monthCustomers,
    required this.monthIncome,
    required this.topServices,
  });

  final int todayCustomers;
  final int todayCompleted;
  final int todayNoShow;
  final double todayIncome;
  final int monthCustomers;
  final double monthIncome;
  final List<ServiceCount> topServices;

  factory BarberStats.fromJson(Map<String, dynamic> json) => BarberStats(
    todayCustomers: json['today_customers'] as int,
    todayCompleted: json['today_completed'] as int,
    todayNoShow: json['today_no_show'] as int,
    todayIncome: (json['today_income'] as num).toDouble(),
    monthCustomers: json['month_customers'] as int,
    monthIncome: (json['month_income'] as num).toDouble(),
    topServices: [for (final s in json['top_services'] as List) ServiceCount.fromJson(s as Map<String, dynamic>)],
  );
}
