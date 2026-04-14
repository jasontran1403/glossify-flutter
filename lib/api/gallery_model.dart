class GalleryModel {
  final int id;
  final String imageUrl;
  final String? description;
  final String uploadedAt;

  GalleryModel({
    required this.id,
    required this.imageUrl,
    this.description,
    required this.uploadedAt,
  });

  factory GalleryModel.fromJson(Map<String, dynamic> json) {
    try {
      final gallery = GalleryModel(
        id: json['id'] as int,
        imageUrl: json['imageUrl']?.toString() ?? '',
        description: json['description']?.toString(),
        uploadedAt: json['uploadedAt']?.toString() ?? '',
      );

      return gallery;

    } catch (e, stackTrace) {
      print('❌ Error in GalleryModel.fromJson: $e');
      print('📦 JSON data: $json');
      print('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }
}