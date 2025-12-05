class StaffSimple {
  final int id;
  final String fullName;
  final String avatar;
  final String description;
  final double rating;

  StaffSimple({
    required this.id,
    required this.fullName,
    required this.avatar,
    required this.description,
    required this.rating,
  });

  factory StaffSimple.fromJson(Map<String, dynamic> json) {
    return StaffSimple(
      id: json['id'],
      fullName: json['fullName'],
      avatar: json['avatar'] ?? '',
      description: json['description'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
    );
  }
}
