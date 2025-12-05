// api_response_model.dart

class ApiResponse<T> {
  final int code;
  final String status;
  final String message;
  final T? data;
  final String time;

  ApiResponse({
    required this.code,
    required this.status,
    required this.message,
    this.data,
    required this.time,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      code: json['code'] as int,
      status: json['status'] as String,
      message: json['message'] as String,
      data: json['data'],
      time: json['time'] as String,
    );
  }

  // ⭐ THÊM: Factory constructor cho error response
  factory ApiResponse.error(String message, {int code = 500}) {
    return ApiResponse(
      code: code,
      status: 'error',
      message: message,
      time: DateTime.now().toIso8601String(),
    );
  }

  // ⭐ THÊM: Factory constructor cho success response (optional)
  factory ApiResponse.success(String message, {T? data}) {
    return ApiResponse(
      code: 900,
      status: 'success',
      message: message,
      data: data,
      time: DateTime.now().toIso8601String(),
    );
  }

  // Add isSuccess getter
  bool get isSuccess => code == 900 && status == 'success';
}

// Thêm helper class để parse page response
class PageResponseParser {
  static List<T> parsePageContent<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    final data = json['data'] as Map<String, dynamic>?;
    final content = data?['content'] as List?;

    return content?.map((item) => fromJson(item as Map<String, dynamic>)).toList() ?? [];
  }
}