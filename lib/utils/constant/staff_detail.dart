import '../../view/home_screen/detail_stylist.dart';

class StaffDetail {
  final int id;
  final String fullName;
  final String description;
  final String avatar;
  final double rating;
  final List<ServiceModel> services;

  StaffDetail({
    required this.id,
    required this.fullName,
    required this.description,
    required this.avatar,
    required this.rating,
    required this.services,
  });

  factory StaffDetail.fromJson(Map<String, dynamic> json) {
    return StaffDetail(
      id: json['id'] != null ? json['id'] as int : 0,
      fullName: json['fullName'] ?? "",
      description: json['description'] ?? "",
      avatar: json['avatar'] ?? "",
      rating: (json['rating'] ?? 0).toDouble(),
      services: (json['services'] as List<dynamic>? ?? [])
          .map((e) => ServiceModel.fromJson(e))
          .toList(),
    );
  }
}
