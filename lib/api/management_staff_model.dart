import 'management_service_model.dart';
import 'management_store_model.dart';

class ManagementStaffDTO {
  final int id;
  final String fullName;
  final String phoneNumber;
  final String email;
  final String avatar;
  final double rating;
  final String role;
  final double shareRate;
  final double tipShareRate;
  final double feeShareRate;
  final ManagementStoreDTO? store;
  final List<ManagementServiceDTO> services;

  ManagementStaffDTO({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    required this.avatar,
    required this.rating,
    required this.role,
    required this.shareRate,
    required this.tipShareRate,
    required this.feeShareRate,
    this.store,
    required this.services,
  });

  factory ManagementStaffDTO.fromJson(Map<String, dynamic> json) {
    return ManagementStaffDTO(
      id: json['id'] as int? ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      role: json['role']?.toString() ?? '',
      shareRate: (json['shareRate'] as num?)?.toDouble() ?? 0.0,
      tipShareRate: (json['tipShareRate'] as num?)?.toDouble() ?? 0.0,
      feeShareRate: (json['feeShareRate'] as num?)?.toDouble() ?? 0.0,
      store: json['store'] != null ? ManagementStoreDTO.fromJson(json['store']) : null,
      services: (json['services'] as List?)?.map((e) => ManagementServiceDTO.fromJson(e)).toList() ?? [],
    );
  }
}