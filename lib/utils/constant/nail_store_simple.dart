class NailStoreSimple {
  final int id;
  final String name;
  final String location;
  final String avt;
  final double rating;      // ✅ Add this
  final int reviews;        // ✅ Add this

  NailStoreSimple({
    required this.id,
    required this.name,
    required this.location,
    required this.avt,
    required this.rating,   // ✅ Add this
    required this.reviews,  // ✅ Add this
  });

  factory NailStoreSimple.fromJson(Map<String, dynamic> json) {
    return NailStoreSimple(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      avt: json['avt'] as String? ?? '',
      rating: (json['rating'] is int)              // ✅ Add this
          ? (json['rating'] as int).toDouble()
          : (json['rating'] as double? ?? 0.0),
      reviews: json['reviews'] as int? ?? 0,       // ✅ Add this
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'avt': avt,
      'rating': rating,    // ✅ Add this
      'reviews': reviews,  // ✅ Add this
    };
  }
}