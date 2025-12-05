// File: lib/api/sales_data_models.dart

class SalesDataResponse {
  final double totalSales;
  final double avgPerDay;
  final double vsLastWeekPercentage;
  final List<DailySales> dailySales;
  final List<TopStaff> topStaff;
  final List<TopService> topServices;

  SalesDataResponse({
    required this.totalSales,
    required this.avgPerDay,
    required this.vsLastWeekPercentage,
    required this.dailySales,
    required this.topStaff,
    required this.topServices,
  });

  factory SalesDataResponse.fromJson(Map<String, dynamic> json) {
    return SalesDataResponse(
      totalSales: (json['totalSales'] ?? 0).toDouble(),
      avgPerDay: (json['avgPerDay'] ?? 0).toDouble(),
      vsLastWeekPercentage: (json['vsLastWeekPercentage'] ?? 0).toDouble(),
      dailySales: (json['dailySales'] as List<dynamic>?)
          ?.map((item) => DailySales.fromJson(item))
          .toList() ??
          [],
      topStaff: (json['topStaff'] as List<dynamic>?)
          ?.map((item) => TopStaff.fromJson(item))
          .toList() ??
          [],
      topServices: (json['topServices'] as List<dynamic>?)
          ?.map((item) => TopService.fromJson(item))
          .toList() ??
          [],
    );
  }
}

class DailySales {
  final String date;
  final String dayLabel;
  final double amount;

  DailySales({
    required this.date,
    required this.dayLabel,
    required this.amount,
  });

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: json['date'] ?? '',
      dayLabel: json['dayLabel'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class TopStaff {
  final int staffId;
  final String name;
  final String? avatar;
  final double sales;

  TopStaff({
    required this.staffId,
    required this.name,
    this.avatar,
    required this.sales,
  });

  factory TopStaff.fromJson(Map<String, dynamic> json) {
    return TopStaff(
      staffId: json['staffId'] ?? 0,
      name: json['name'] ?? '',
      avatar: json['avatar'],
      sales: (json['sales'] ?? 0).toDouble(),
    );
  }
}

class TopService {
  final int serviceId;
  final String name;
  final double sales;
  final double percentage;

  TopService({
    required this.serviceId,
    required this.name,
    required this.sales,
    required this.percentage,
  });

  factory TopService.fromJson(Map<String, dynamic> json) {
    return TopService(
      serviceId: json['serviceId'] ?? 0,
      name: json['name'] ?? '',
      sales: (json['sales'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}