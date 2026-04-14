class QuickServiceModel {
  final int id;
  final String name;
  final String avatar;
  final String description;
  final double price;
  final String categoryName;
  final int time;
  final List<QuickStaffModel> staffList;

  QuickServiceModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.description,
    required this.price,
    required this.categoryName,
    required this.time,
    required this.staffList,
  });

  factory QuickServiceModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> staffJson = json['staffList'] ?? [];
    return QuickServiceModel(
      id: json['serviceId'] ?? json['id'] ?? 0,
      name: json['serviceName'] ?? json['name'] ?? '',
      avatar: json['serviceAvt'] ?? json['avatar'] ?? '',
      description: json['serviceDescription'] ?? json['description'] ?? '',
      price: (json['servicePrice'] ?? json['price'] ?? 0.0).toDouble(),
      categoryName: json['cateName'] ?? json['categoryName'] ?? '',
      time: json['time'] ?? 0,
      staffList: staffJson.map((s) => QuickStaffModel.fromJson(s)).toList(),
    );
  }
}

class QuickStaffModel {
  final int id;
  final String fullName;

  QuickStaffModel({
    required this.id,
    required this.fullName,
  });

  factory QuickStaffModel.fromJson(Map<String, dynamic> json) {
    return QuickStaffModel(
      id: json['id'] ?? json['staffId'] ?? 0,
      fullName: json['fullName'] ?? json['staffFullName'] ?? '',
    );
  }
}