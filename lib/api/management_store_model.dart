import 'management_category_model.dart';

class ManagementStoreDTO {
  final int id;
  final String name;
  final String location;
  final String avatar;
  final List<ManagementCategoryDTO> categories;

  ManagementStoreDTO({
    required this.id,
    required this.name,
    required this.location,
    required this.avatar,
    required this.categories,
  });

  factory ManagementStoreDTO.fromJson(Map<String, dynamic> json) {
    final store = ManagementStoreDTO(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      categories: (json['categories'] as List?)?.map((e) => ManagementCategoryDTO.fromJson(e)).toList() ?? [],
    );

    return store;
  }
}

class ManagementStoreUpdateRequest {
  final String? name;
  final String? location;
  final String? avatar;
  final List<int>? categoryIds;

  ManagementStoreUpdateRequest({this.name, this.location, this.avatar, this.categoryIds});

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (location != null) 'location': location,
      if (avatar != null) 'avatar': avatar,
      if (categoryIds != null) 'categoryIds': categoryIds,
    };
  }
}