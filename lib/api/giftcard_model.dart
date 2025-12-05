class GiftCardDTO {
  final String code;
  final double remainingBalance;
  final DateTime? lastUpdate; // Chỉ 1 field
  final String status;

  GiftCardDTO({
    required this.code,
    required this.remainingBalance,
    this.lastUpdate,
    required this.status,
  });

  factory GiftCardDTO.fromJson(Map<String, dynamic> json) {
    return GiftCardDTO(
      code: json['code'],
      remainingBalance: (json['remainingBalance'] as num).toDouble(),
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
      status: json['status'],
    );
  }
}