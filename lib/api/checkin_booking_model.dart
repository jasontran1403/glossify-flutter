// models/checkin_booking_model.dart
class CheckinBookingResponse {
  final List<CheckinBookingDTO> bookings;
  final int currentPage;
  final int totalPages;
  final int totalItems;

  CheckinBookingResponse({
    required this.bookings,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
  });

  factory CheckinBookingResponse.fromJson(Map<String, dynamic> json) {
    return CheckinBookingResponse(
      bookings: (json['content'] as List)
          .map((e) => CheckinBookingDTO.fromJson(e))
          .toList(),
      currentPage: json['number'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      totalItems: json['totalElements'] ?? 0,
    );
  }
}

class CheckinBookingDTO {
  final int id;
  final String customerName;
  final String customerAvt;
  final String customerPhone;
  final String startTime;
  final List<CheckinBookingServiceDTO> bookingServices;

  CheckinBookingDTO({
    required this.id,
    required this.customerName,
    required this.customerAvt,
    required this.customerPhone,
    required this.startTime,
    required this.bookingServices,
  });

  factory CheckinBookingDTO.fromJson(Map<String, dynamic> json) {
    return CheckinBookingDTO(
      id: json['id'] as int,
      customerName: json['customerName'] ?? '',
      customerAvt: json['customerAvt'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      startTime: json['startTime'] ?? '',
      bookingServices: (json['bookingServices'] as List?)
          ?.map((e) => CheckinBookingServiceDTO.fromJson(e))
          .toList() ?? [],
    );
  }

  DateTime get parsedStartTime {
    return DateTime.parse(startTime).toLocal();
  }

  List<String> get serviceNames {
    return bookingServices.map((service) => service.service?.name ?? '').toList();
  }

  List<CheckinStaffDTO> get staffList {
    return bookingServices
        .map((service) => service.staff)
        .whereType<CheckinStaffDTO>()
        .toList();
  }

  List<String> get staffNames {
    return staffList.map((staff) => staff.fullName).toList();
  }

  List<String> get staffAvatars {
    return staffList
        .map((staff) => staff.staffAvt)
        .where((avatar) => avatar.isNotEmpty)
        .toList();
  }

  double get totalAmount {
    return bookingServices.fold(0.0, (sum, service) => sum + (service.service?.price ?? 0));
  }
}

class CheckinBookingServiceDTO {
  final int id;
  final CheckinServiceDTO? service;
  final CheckinStaffDTO? staff;

  CheckinBookingServiceDTO({
    required this.id,
    this.service,
    this.staff,
  });

  factory CheckinBookingServiceDTO.fromJson(Map<String, dynamic> json) {
    return CheckinBookingServiceDTO(
      id: json['id'] as int,
      service: json['service'] != null ? CheckinServiceDTO.fromJson(json['service']) : null,
      staff: json['staff'] != null ? CheckinStaffDTO.fromJson(json['staff']) : null,
    );
  }
}

class CheckinServiceDTO {
  final int id;
  final String name;
  final double? price;
  final String? description;
  final double? cashPrice;
  final String? avt;
  final bool plus;

  CheckinServiceDTO({
    required this.id,
    required this.name,
    this.price,
    this.description,
    this.cashPrice,
    this.avt,
    required this.plus,
  });

  factory CheckinServiceDTO.fromJson(Map<String, dynamic> json) {
    return CheckinServiceDTO(
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

class CheckinStaffDTO {
  final int id;
  final String fullName;
  final String staffAvt;
  final double rating;

  CheckinStaffDTO({
    required this.id,
    required this.fullName,
    required this.staffAvt,
    required this.rating,
  });

  factory CheckinStaffDTO.fromJson(Map<String, dynamic> json) {
    return CheckinStaffDTO(
      id: json['id'] as int,
      fullName: json['fullName'] ?? '',
      staffAvt: json['staffAvt'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }
}