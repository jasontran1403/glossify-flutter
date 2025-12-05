class PageResponseParser {
  static List<T> parsePageContent<T>(
      Map<String, dynamic> jsonResponse,
      T Function(Map<String, dynamic>) fromJson,
      ) {
    if (jsonResponse['data'] == null) return [];

    final data = jsonResponse['data'];

    // Check if data is a Page object with 'content' field
    if (data is Map<String, dynamic> && data.containsKey('content')) {
      final List<dynamic> content = data['content'] as List<dynamic>;
      return content
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Otherwise, assume data is directly a list
    if (data is List) {
      return data
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }
}
