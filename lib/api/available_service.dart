// available_service.dart
class AvailableService {
  final int serviceId;
  final String serviceName;
  final double price;
  final int duration;
  final bool alreadyInBooking;
  final int? bookingServiceId;
  final String? currentStaffName;

  AvailableService({
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.duration,
    required this.alreadyInBooking,
    this.bookingServiceId,
    this.currentStaffName,
  });

  factory AvailableService.fromJson(Map<String, dynamic> json) {
    return AvailableService(
      serviceId: json['serviceId'],
      serviceName: json['serviceName'],
      price: json['price']?.toDouble() ?? 0.0,
      duration: json['duration'] ?? 15,
      alreadyInBooking: json['alreadyInBooking'] ?? false,
      bookingServiceId: json['bookingServiceId'],
      currentStaffName: json['currentStaffName'],
    );
  }
}

// new_service_request.dart
class NewServiceRequest {
  final int serviceId;
  final double? price;

  NewServiceRequest({
    required this.serviceId,
    this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'serviceId': serviceId,
      if (price != null) 'price': price,
    };
  }
}