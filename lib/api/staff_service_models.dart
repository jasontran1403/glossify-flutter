// ============================================================================
// Flutter Models for Staff Services Management
// ============================================================================
// Location: lib/api/staff_service_models.dart
// ============================================================================

class ServiceDTO {
  final int id;
  final String name;
  final double price;
  final String? description;
  final double? cashPrice;
  final String? avatar;
  final bool plus;
  final int? categoryId;
  final String? categoryName;

  ServiceDTO({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.cashPrice,
    this.avatar,
    required this.plus,
    this.categoryId,
    this.categoryName,
  });

  factory ServiceDTO.fromJson(Map<String, dynamic> json) {
    return ServiceDTO(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      description: json['description'],
      cashPrice: json['cashPrice'] != null ? (json['cashPrice'] as num).toDouble() : null,
      avatar: json['avatar'],
      plus: json['plus'] ?? false,
      categoryId: json['categoryId'],
      categoryName: json['categoryName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'cashPrice': cashPrice,
      'avatar': avatar,
      'plus': plus,
      'categoryId': categoryId,
      'categoryName': categoryName,
    };
  }
}

class AvailableServicesDTO {
  final int staffId;
  final String staffName;
  final int storeId;
  final String storeName;
  final List<ServiceDTO> availableServices; // Services not yet assigned
  final List<ServiceDTO> currentServices;   // Services already assigned

  AvailableServicesDTO({
    required this.staffId,
    required this.staffName,
    required this.storeId,
    required this.storeName,
    required this.availableServices,
    required this.currentServices,
  });

  factory AvailableServicesDTO.fromJson(Map<String, dynamic> json) {
    return AvailableServicesDTO(
      staffId: json['staffId'],
      staffName: json['staffName'],
      storeId: json['storeId'],
      storeName: json['storeName'],
      availableServices: (json['availableServices'] as List<dynamic>)
          .map((e) => ServiceDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentServices: (json['currentServices'] as List<dynamic>)
          .map((e) => ServiceDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StaffServiceOperationResult {
  final int staffId;
  final String staffName;
  final String operation; // "ADD" or "REMOVE"
  final int servicesAffected;
  final List<ServiceDTO> currentServices;
  final String message;

  StaffServiceOperationResult({
    required this.staffId,
    required this.staffName,
    required this.operation,
    required this.servicesAffected,
    required this.currentServices,
    required this.message,
  });

  factory StaffServiceOperationResult.fromJson(Map<String, dynamic> json) {
    return StaffServiceOperationResult(
      staffId: json['staffId'],
      staffName: json['staffName'],
      operation: json['operation'],
      servicesAffected: json['servicesAffected'],
      currentServices: (json['currentServices'] as List<dynamic>)
          .map((e) => ServiceDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'],
    );
  }
}

class AddServicesToStaffRequest {
  final List<int> serviceIds;

  AddServicesToStaffRequest({required this.serviceIds});

  Map<String, dynamic> toJson() {
    return {
      'serviceIds': serviceIds,
    };
  }
}