class NailStoreSimple {
  final int id;
  final String name;
  final String location;
  final String avt;

  NailStoreSimple({
    required this.id,
    required this.name,
    required this.location,
    required this.avt,
  });

  factory NailStoreSimple.fromJson(Map<String, dynamic> json) {
    return NailStoreSimple(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      avt: json['avt'],
    );
  }
}
