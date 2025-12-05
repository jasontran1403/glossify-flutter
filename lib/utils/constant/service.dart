class ServiceModel {
  final int id;
  final String name;
  final double price;
  final String cateDescription;
  final List<Staff> staffList;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    required this.cateDescription,
    required this.staffList,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      cateDescription: json['cateDescription'] ?? 'No description',
      staffList: (json['staffList'] as List<dynamic>?)
          ?.map((e) => Staff.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class Staff {
  final int id;
  final String fullName;
  final String avatar;

  Staff({required this.id, required this.fullName, required this.avatar});

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      fullName: json['fullName'],
      avatar: json['avatar'] ?? '',
    );
  }
}
