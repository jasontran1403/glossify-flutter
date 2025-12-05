import 'cate_model.dart';

class NailStoreModel {
  final int id;
  final String storeName;
  final String location;
  final List<CategoryModel> categories;

  NailStoreModel({
    required this.id,
    required this.storeName,
    required this.location,
    required this.categories,
  });

  factory NailStoreModel.fromJson(Map<String, dynamic> json) {
    return NailStoreModel(
      id: json['id'] ?? 0,
      storeName: json['storeName'] ?? '',
      location: json['location'] ?? '',
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => CategoryModel.fromJson(e))
          .toList() ??
          [],
    );
  }
}