// models/clients_per_day_data.dart
class ClientsPerDayData {
  final int totalClients;
  final double percentChange;
  final int avgPerDay;
  final List<Map<String, dynamic>> barChart; // dùng cho biểu đồ cột kép (peak/slow)
  final Map<String, List<double>> heatmap;   // key: 'MON', 'TUE', ...

  ClientsPerDayData({
    required this.totalClients,
    required this.percentChange,
    required this.avgPerDay,
    required this.barChart,
    required this.heatmap,
  });

  /// Getter để hiển thị % so sánh tuần trước (làm tròn)
  int get weekComparisonPercent => percentChange.round();

  factory ClientsPerDayData.fromJson(Map<String, dynamic> json) {
    // 1. totalClients & percentChange
    final int totalClients = (json['totalClients'] as num?)?.toInt() ?? 0;
    final double percentChange = (json['percentChange'] as num?)?.toDouble() ?? 0.0;

    // 2. weekData → barChart (dùng peak + slow từ backend)
    final List<dynamic> weekDataRaw = json['weekData'] ?? [];
    final List<Map<String, dynamic>> barChart = weekDataRaw.map((item) {
      final String day = (item['day'] as String?)?.toUpperCase() ?? 'UNKNOWN';
      final int peak = (item['peak'] as num?)?.toInt() ?? 0;
      final int slow = (item['slow'] as num?)?.toInt() ?? 0;

      return {
        'day': day,
        'peak': peak.toDouble(),
        'slow': slow.toDouble(),
      };
    }).toList();

    // 3. heatmapData
    final List<dynamic> heatmapDataRaw = json['heatmapData'] ?? [];
    final Map<String, List<double>> heatmap = {};

    for (var item in heatmapDataRaw) {
      final String dayLabel = (item['dayLabel'] as String?)?.toUpperCase() ?? 'UNKNOWN';
      final List<dynamic>? hoursRaw = item['hours'] as List<dynamic>?;

      final List<double> hours = hoursRaw
          ?.map((h) => (h as num?)?.toDouble() ?? 0.0)
          .toList() ??
          List.filled(10, 0.0);

      heatmap[dayLabel] = hours;
    }

    // 4. avgPerDay
    final int activeDays = weekDataRaw
        .where((item) {
      final peak = item['peak'];
      return peak is num && peak > 0;
    })
        .length;

    final int avgPerDay = activeDays > 0 ? totalClients ~/ activeDays : 0;

    return ClientsPerDayData(
      totalClients: totalClients,
      percentChange: percentChange,
      avgPerDay: avgPerDay,
      barChart: barChart,
      heatmap: heatmap,
    );
  }
}