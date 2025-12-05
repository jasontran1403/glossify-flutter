// Model cho Store Info
class StoreInfo {
  final int id;
  final String name;
  final String location;
  final String? avt;
  final double fee;
  final double ownerRate;

  StoreInfo({
    required this.id,
    required this.name,
    required this.location,
    this.avt,
    required this.fee,
    required this.ownerRate,
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      location: json['location'] as String,
      avt: json['avt'] as String?,
      fee: (json['fee'] as num).toDouble(),
      ownerRate: (json['ownerRate'] as num).toDouble(),
    );
  }
}
