class ReviewModel {
  final int id;
  final String reviewId;
  final String name;
  final double rating;
  final String text;
  final int createdAt;
  final int editedAt;
  final String avatarUrl;
  final List<String> photos;

  ReviewModel({
    required this.id,
    required this.reviewId,
    required this.name,
    required this.rating,
    required this.text,
    required this.createdAt,
    required this.editedAt,
    required this.avatarUrl,
    required this.photos,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    // Handle photos array (can be array of objects or array of strings)
    List<String> photoUrls = [];
    if (json['photos'] != null) {
      final photos = json['photos'] as List;
      photoUrls = photos.map((photo) {
        if (photo is String) {
          return photo;
        } else if (photo is Map<String, dynamic>) {
          return photo['url'] as String;
        }
        return '';
      }).where((url) => url.isNotEmpty).toList();
    }

    return ReviewModel(
      id: json['id'] as int,
      reviewId: json['reviewId'] as String,
      name: json['name'] as String,
      rating: (json['rating'] as num).toDouble(),
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] as int,
      editedAt: json['editedAt'] as int,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      photos: photoUrls,
    );
  }

  // Helper to get formatted date
  String get formattedDate {
    try {
      // ✅ Convert microseconds to milliseconds
      // Chia cho 1000 để convert từ microseconds sang milliseconds
      final milliseconds = createdAt ~/ 1000;

      final date = DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes} minutes ago';
        }
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? "month" : "months"} ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? "year" : "years"} ago';
      }
    } catch (e) {
      print('❌ Error formatting date: $e');
      return 'Unknown date';
    }
  }
}