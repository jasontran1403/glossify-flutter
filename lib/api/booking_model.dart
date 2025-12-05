// models/booking_history_model.dart
class BookingHistoryResponse {
  final List<BookingHistoryDTO> bookings;
  final double accumulateTip;
  final double accumulateShare;

  BookingHistoryResponse({
    required this.bookings,
    required this.accumulateTip,
    required this.accumulateShare,
  });

  factory BookingHistoryResponse.fromJson(Map<String, dynamic> json) {
    return BookingHistoryResponse(
      bookings: (json['bookings']['content'] as List)
          .map((e) => BookingHistoryDTO.fromJson(e))
          .toList(),
      accumulateTip: (json['accumulateTip'] as num).toDouble(),
      accumulateShare: (json['accumulateShare'] as num).toDouble(),
    );
  }
}

class BookingHistoryDTO {
  final int id;
  final String customerName;
  final String customerPhone;
  final String location;
  final double tip;
  final int paymentMethod;
  final String status;
  final List<BookingHistoryService> bookingServices;
  final String startTime;
  final BookingStaffSimple? staff;
  final BookingCustomer? customer;

  BookingHistoryDTO({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.location,
    required this.tip,
    required this.paymentMethod,
    required this.status,
    required this.bookingServices,
    required this.startTime,
    this.staff,
    this.customer,
  });

  factory BookingHistoryDTO.fromJson(Map<String, dynamic> json) {
    return BookingHistoryDTO(
      id: json['id'] as int,
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      location: json['location'] ?? '',
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as int? ?? 0,
      status: json['status'] ?? '',
      bookingServices: (json['bookingServices'] as List?)
          ?.map((e) => BookingHistoryService.fromJson(e))
          .toList() ?? [],
      startTime: json['startTime'] ?? '',
      staff: json['staff'] != null ? BookingStaffSimple.fromJson(json['staff']) : null,
      customer: json['customerId'] != null ? BookingCustomer.fromJson(json['customerId']) : null,
    );
  }

  double get totalAmount {
    return bookingServices.fold(0.0, (sum, service) => sum + (service.price ?? 0));
  }

  List<String> get serviceNames {
    return bookingServices.map((service) => service.service?.name ?? '').toList();
  }

  DateTime get parsedStartTime {
    return DateTime.parse(startTime).toLocal();
  }
}

class BookingHistoryService {
  final int id;
  final BookingServiceEntity? service;
  final double? price;

  BookingHistoryService({
    required this.id,
    this.service,
    this.price,
  });

  factory BookingHistoryService.fromJson(Map<String, dynamic> json) {
    return BookingHistoryService(
      id: json['id'] as int,
      service: json['service'] != null ? BookingServiceEntity.fromJson(json['service']) : null,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

class BookingServiceEntity {
  final int id;
  final String name;
  final double? price;
  final String? description;
  final double? cashPrice;
  final String? avt;
  final bool plus;

  BookingServiceEntity({
    required this.id,
    required this.name,
    this.price,
    this.description,
    this.cashPrice,
    this.avt,
    required this.plus,
  });

  factory BookingServiceEntity.fromJson(Map<String, dynamic> json) {
    return BookingServiceEntity(
      id: json['id'] as int,
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble(),
      description: json['description'],
      cashPrice: (json['cashPrice'] as num?)?.toDouble(),
      avt: json['avt'],
      plus: json['plus'] ?? false,
    );
  }
}

class BookingStaffSimple {
  final int id;
  final String fullName;
  final String? avatar;
  final double rating;

  BookingStaffSimple({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.rating,
  });

  factory BookingStaffSimple.fromJson(Map<String, dynamic> json) {
    return BookingStaffSimple(
      id: json['id'] as int,
      fullName: json['fullName'] ?? '',
      avatar: json['avatar'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BookingCustomer {
  final int id;
  final String fullName;
  final String? avatar;

  BookingCustomer({
    required this.id,
    required this.fullName,
    this.avatar,
  });

  factory BookingCustomer.fromJson(Map<String, dynamic> json) {
    return BookingCustomer(
      id: json['id'] as int,
      fullName: json['fullName'] ?? '',
      avatar: json['avatar'],
    );
  }
}