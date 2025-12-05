// lib/api/heatmap_api_response.dart
class HeatmapApiResponse {
  final int code;
  final String status;
  final String message;
  final Map<String, dynamic>? data;  // ← chắc chắn là Map<String, dynamic>
  final String time;

  HeatmapApiResponse({
    required this.code,
    required this.status,
    required this.message,
    this.data,
    required this.time,
  });

  factory HeatmapApiResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;
    if (json['data'] != null) {
      parsedData = Map<String, dynamic>.from(json['data'] as Map);
    }

    return HeatmapApiResponse(
      code: json['code'] as int? ?? 0,
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String? ?? '',
      data: parsedData,
      time: json['time'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  bool get isSuccess => code == 900 && status == 'success';
}