import 'management_service_model.dart';

class ManagementCategoryDTO {
  final int id;
  final String name;
  final String description;
  final String avatar;
  final List<ManagementServiceDTO> services; // BỎ DẤU ?

  ManagementCategoryDTO({
    required this.id,
    required this.name,
    required this.description,
    required this.avatar,
    required this.services, // BỎ DẤU ?
  });

  factory ManagementCategoryDTO.fromJson(Map<String, dynamic> json) {
    final servicesJson = json['services'] as List?;

    final category = ManagementCategoryDTO(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'No Name',
      description: json['description']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      services: servicesJson?.map((e) {
        return ManagementServiceDTO.fromJson(e);
      }).toList() ?? [], // MẶC ĐỊNH LÀ EMPTY LIST
    );

    return category;
  }
}

class ManagementCategoryUpdateRequest {
  final String? name;
  final String? description;
  final String? avatar;
  final List<int>? serviceIds;

  ManagementCategoryUpdateRequest({this.name, this.description, this.avatar, this.serviceIds});

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatar != null) 'avatar': avatar,
      if (serviceIds != null) 'serviceIds': serviceIds,
    };
  }
}