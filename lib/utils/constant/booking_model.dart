class BookingDTO {
  final int id;
  final String customerName;
  final String customerPhone;
  final String status;
  final String startTime;
  final double totalPrice;
  final double tip;
  final int paymentMethod; // 👈 thêm
  final List<BookingServiceDTO> bookingServices;

  BookingDTO({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.startTime,
    required this.totalPrice,
    required this.tip,
    required this.paymentMethod,
    required this.bookingServices,
  });

  factory BookingDTO.fromJson(Map<String, dynamic> json) {
    return BookingDTO(
      id: json['id'],
      customerName: json['customerName'],
      customerPhone: json['customerPhone'],
      status: json['status'],
      startTime: json['startTime'],
      totalPrice: (json['totalPrice'] as num).toDouble(),
      tip: (json['tip'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 0,
      bookingServices: (json['bookingServices'] as List)
          .map((e) => BookingServiceDTO.fromJson(e))
          .toList(),
    );
  }
}


class BookingServiceDTO {
  final int id;
  final ServiceDTO service;
  final StaffDTO? staff; // Added to match sample data, nullable in case it's missing

  BookingServiceDTO({required this.id, required this.service, this.staff});

  factory BookingServiceDTO.fromJson(Map<String, dynamic> json) {
    return BookingServiceDTO(
      id: json['id'],
      service: ServiceDTO.fromJson(json['service']),
      staff: json['staff'] != null ? StaffDTO.fromJson(json['staff']) : null,
    );
  }
}

class ServiceDTO {
  final int id;
  final String name;
  final double price;
  final String categoryName;
  final String? note; // 👈 thêm

  ServiceDTO({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryName,
    this.note,
  });

  factory ServiceDTO.fromJson(Map<String, dynamic> json) {
    return ServiceDTO(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      categoryName: json['categoryName'] ?? '',
      note: json['note'], // 👈 thêm
    );
  }
}

class StaffDTO {
  final int id;
  final String fullName;

  StaffDTO({
    required this.id,
    required this.fullName,
  });

  factory StaffDTO.fromJson(Map<String, dynamic> json) {
    return StaffDTO(
      id: json['id'],
      fullName: json['fullName'],
    );
  }
}