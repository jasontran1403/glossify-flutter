class Booking {
  final int id;
  final String customerName;
  final String customerPhone;
  final String status;
  final String location;
  final String startTime;
  final double totalPrice;
  final List<BookingService> bookingServices;

  Booking({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.location,
    required this.startTime,
    required this.totalPrice,
    required this.bookingServices,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id']?.toInt() ?? 0,
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      status: json['status'] ?? '',
      location: json['location'] ?? '',
      startTime: json['startTime'] ?? '',
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      bookingServices: (json['bookingServices'] as List<dynamic>?)
          ?.map((service) => BookingService.fromJson(service))
          .toList() ?? [],
    );
  }
}

class BookingService {
  final int id;
  final String serviceName;
  final double price;
  final int duration;

  BookingService({
    required this.id,
    required this.serviceName,
    required this.price,
    required this.duration,
  });

  factory BookingService.fromJson(Map<String, dynamic> json) {
    return BookingService(
      id: json['id']?.toInt() ?? 0,
      serviceName: json['serviceName'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      duration: json['duration']?.toInt() ?? 0,
    );
  }
}