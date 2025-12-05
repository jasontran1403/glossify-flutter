class BookingData {
  final int id;
  final String customerName;
  final String customerPhone;
  final String status;
  final String startTime;
  final double totalPrice;
  final List<BookingServiceData> bookingServices;

  BookingData({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.startTime,
    required this.totalPrice,
    required this.bookingServices,
  });

  factory BookingData.fromJson(Map<String, dynamic> json) {
    return BookingData(
      id: json['id']?.toInt() ?? 0,
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      status: json['status'] ?? '',
      startTime: json['startTime'] ?? '',
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      bookingServices: (json['bookingServices'] as List<dynamic>?)
          ?.map((service) => BookingServiceData.fromJson(service))
          .toList() ?? [],
    );
  }
}

class BookingServiceData {
  final int id;
  final String serviceName;
  final double price;
  final int duration;

  BookingServiceData({
    required this.id,
    required this.serviceName,
    required this.price,
    required this.duration,
  });

  factory BookingServiceData.fromJson(Map<String, dynamic> json) {
    return BookingServiceData(
      id: json['id']?.toInt() ?? 0,
      serviceName: json['serviceName'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      duration: json['duration']?.toInt() ?? 0,
    );
  }
}