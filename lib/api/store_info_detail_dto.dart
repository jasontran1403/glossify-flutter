class StoreInfoDetailDTO {
  final int id;
  final String name;
  final String location;
  final String avt;
  final double fee;
  final double ownerRate;
  final double? lon;
  final double? lat;
  final int? defaultService;

  StoreInfoDetailDTO({
    required this.id,
    required this.name,
    required this.location,
    required this.avt,
    required this.fee,
    required this.ownerRate,
    this.lon,
    this.lat,
    this.defaultService,
  });

  factory StoreInfoDetailDTO.fromJson(Map<String, dynamic> json) {
    return StoreInfoDetailDTO(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      avt: json['avt'] as String? ?? '',
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      ownerRate: (json['ownerRate'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      defaultService: json['defaultService'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'avt': avt,
      'fee': fee,
      'ownerRate': ownerRate,
      'lon': lon,
      'lat': lat,
      'defaultService': defaultService,
    };
  }
}
