class UserListDTO {
  final int id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String avatar;

  UserListDTO({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.avatar,
  });

  factory UserListDTO.fromJson(Map<String, dynamic> json) {
    return UserListDTO(
      id: json['id'] as int,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
    );
  }
}
