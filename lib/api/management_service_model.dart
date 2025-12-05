import 'management_category_model.dart';

class ManagementServiceDTO {
  final int id;
  final String name;
  final double price;
  final String description;
  final double cashPrice;
  final String avatar;
  final bool plus;
  final ManagementCategoryDTO? category;

  ManagementServiceDTO({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.cashPrice,
    required this.avatar,
    required this.plus,
    this.category,
  });

  factory ManagementServiceDTO.fromJson(Map<String, dynamic> json) {
    return ManagementServiceDTO(
      id: json['id'] as int,
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      cashPrice: (json['cashPrice'] as num?)?.toDouble() ?? 0.0,
      avatar: json['avatar'] ?? '',
      plus: json['plus'] ?? false,
      category: json['category'] != null ? ManagementCategoryDTO.fromJson(json['category']) : null,
    );
  }
}

class ManagementServiceUpdateRequest {
  final String? name;
  final double? price;
  final String? description;
  final double? cashPrice;
  final String? avatar;
  final bool? plus;
  final int? categoryId;

  ManagementServiceUpdateRequest({
    this.name,
    this.price,
    this.description,
    this.cashPrice,
    this.avatar,
    this.plus,
    this.categoryId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (description != null) 'description': description,
      if (cashPrice != null) 'cashPrice': cashPrice,
      if (avatar != null) 'avatar': avatar,
      if (plus != null) 'plus': plus,
      if (categoryId != null) 'categoryId': categoryId,
    };
  }
}