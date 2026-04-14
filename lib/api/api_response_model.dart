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

class PageResponseParser {
  /// Parse content array from Spring Page response
  static List<T> parsePageContent<T>(
      Map<String, dynamic> pageData,
      T Function(Map<String, dynamic>) fromJson,
      ) {
    if (!pageData.containsKey('content')) {
      return [];
    }

    final content = pageData['content'];
    if (content is! List) {
      return [];
    }

    final List<T> results = [];

    for (int i = 0; i < content.length; i++) {
      try {
        final item = content[i];
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final parsed = fromJson(item);
        results.add(parsed);

      } catch (e, stackTrace) {
        print('❌ Error parsing item $i: $e');
        print('📦 Item data: ${content[i]}');
        print('📚 Stack trace: $stackTrace');
      }
    }

    return results;
  }

  /// Get total pages from Page response
  static int getTotalPages(Map<String, dynamic> pageData) {
    return pageData['totalPages'] ?? 0;
  }

  /// Get total elements from Page response
  static int getTotalElements(Map<String, dynamic> pageData) {
    return pageData['totalElements'] ?? 0;
  }

  /// Check if current page is the last page
  static bool isLastPage(Map<String, dynamic> pageData) {
    return pageData['last'] ?? true;
  }

  /// Check if current page is the first page
  static bool isFirstPage(Map<String, dynamic> pageData) {
    return pageData['first'] ?? true;
  }
}
