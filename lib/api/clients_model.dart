// ============================================================================
// Flutter Models for Clients Statistics
// ============================================================================
// Location: lib/api/models/clients_models.dart
// ============================================================================

class ClientsStatisticsResponse {
  final int totalClients;
  final double retentionRate;
  final int newClients;
  final int returningClients;
  final List<DailyClientData> dailyData;
  final List<TopStaffClient> topStaff;
  final List<TopServiceClient> topServices;
  final List<TopTimeWindow> topTimeWindows;

  ClientsStatisticsResponse({
    required this.totalClients,
    required this.retentionRate,
    required this.newClients,
    required this.returningClients,
    required this.dailyData,
    required this.topStaff,
    required this.topServices,
    required this.topTimeWindows,
  });

  factory ClientsStatisticsResponse.fromJson(Map<String, dynamic> json) {
    return ClientsStatisticsResponse(
      totalClients: json['totalClients'] ?? 0,
      retentionRate: (json['retentionRate'] ?? 0.0).toDouble(),
      newClients: json['newClients'] ?? 0,
      returningClients: json['returningClients'] ?? 0,
      dailyData: (json['dailyData'] as List<dynamic>?)
          ?.map((e) => DailyClientData.fromJson(e))
          .toList() ??
          [],
      topStaff: (json['topStaff'] as List<dynamic>?)
          ?.map((e) => TopStaffClient.fromJson(e))
          .toList() ??
          [],
      topServices: (json['topServices'] as List<dynamic>?)
          ?.map((e) => TopServiceClient.fromJson(e))
          .toList() ??
          [],
      topTimeWindows: (json['topTimeWindows'] as List<dynamic>?)
          ?.map((e) => TopTimeWindow.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class DailyClientData {
  final String date;
  final int newClientsCount;
  final double retentionRate;
  final int totalClientsDay;

  DailyClientData({
    required this.date,
    required this.newClientsCount,
    required this.retentionRate,
    required this.totalClientsDay,
  });

  factory DailyClientData.fromJson(Map<String, dynamic> json) {
    return DailyClientData(
      date: json['date'] ?? '',
      newClientsCount: json['newClientsCount'] ?? 0,
      retentionRate: (json['retentionRate'] ?? 0.0).toDouble(),
      totalClientsDay: json['totalClientsDay'] ?? 0,
    );
  }

  // Helper to get formatted date for chart
  String get formattedDate {
    try {
      final DateTime dt = DateTime.parse(date);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }
}

class TopStaffClient {
  final int staffId;
  final String staffName;
  final String? staffAvatar;
  final int clientCount;

  TopStaffClient({
    required this.staffId,
    required this.staffName,
    this.staffAvatar,
    required this.clientCount,
  });

  factory TopStaffClient.fromJson(Map<String, dynamic> json) {
    return TopStaffClient(
      staffId: json['staffId'] ?? 0,
      staffName: json['staffName'] ?? 'Unknown',
      staffAvatar: json['staffAvatar'],
      clientCount: json['clientCount'] ?? 0,
    );
  }
}

class TopServiceClient {
  final int serviceId;
  final String serviceName;
  final String? categoryName;
  final int clientCount;

  TopServiceClient({
    required this.serviceId,
    required this.serviceName,
    this.categoryName,
    required this.clientCount,
  });

  factory TopServiceClient.fromJson(Map<String, dynamic> json) {
    return TopServiceClient(
      serviceId: json['serviceId'] ?? 0,
      serviceName: json['serviceName'] ?? 'Unknown',
      categoryName: json['categoryName'],
      clientCount: json['clientCount'] ?? 0,
    );
  }
}

class TopTimeWindow {
  final String timeWindow;
  final int clientCount;

  TopTimeWindow({
    required this.timeWindow,
    required this.clientCount,
  });

  factory TopTimeWindow.fromJson(Map<String, dynamic> json) {
    return TopTimeWindow(
      timeWindow: json['timeWindow'] ?? '',
      clientCount: json['clientCount'] ?? 0,
    );
  }
}

// ============================================================================
// USAGE EXAMPLE:
// ============================================================================
//
// final response = await ApiService.getClientsStatistics(
//   startDate: DateTime(2025, 10, 1),
//   endDate: DateTime.now(),
// );
//
// if (response.isSuccess && response.data != null) {
//   final stats = ClientsStatisticsResponse.fromJson(response.data!);
//   
//   print('Total Clients: ${stats.totalClients}');
//   print('Retention Rate: ${stats.retentionRate}%');
//   print('New Clients: ${stats.newClients}');
//   print('Returning Clients: ${stats.returningClients}');
//   
//   // Chart data
//   for (var day in stats.dailyData) {
//     print('${day.date}: ${day.newClientsCount} new, ${day.retentionRate}% retention');
//   }
//   
//   // Top staff
//   for (var staff in stats.topStaff) {
//     print('${staff.staffName}: ${staff.clientCount} clients');
//   }
// }
//
// ============================================================================