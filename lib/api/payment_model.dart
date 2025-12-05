// models/payment_model.dart
class PaymentHistoryResponse {
  final List<PaymentHistoryDTO> payments;
  final double totalRevenue;
  final double todayRevenue;

  PaymentHistoryResponse({
    required this.payments,
    required this.totalRevenue,
    required this.todayRevenue,
  });

  factory PaymentHistoryResponse.fromJson(Map<String, dynamic> json) {
    // Xử lý trường hợp payments có thể là null hoặc empty
    List<PaymentHistoryDTO> paymentsList = [];

    if (json['payments'] != null && json['payments']['content'] != null) {
      final content = json['payments']['content'];
      if (content is List) {
        paymentsList = content
            .map((e) => PaymentHistoryDTO.fromJson(e))
            .toList();
      }
    }

    return PaymentHistoryResponse(
      payments: paymentsList,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      todayRevenue: (json['todayRevenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PaymentHistoryDTO {
  final int id;
  final String customerName;
  final String customerAvt;
  final String customerPhone;
  final String startTime;
  final String status;
  final double tip;
  final int paymentMethod;
  final List<PaymentServiceDTO> bookingServices;
  final double totalCreditAmount;
  final double totalCashAmount;

  PaymentHistoryDTO({
    required this.id,
    required this.customerName,
    required this.customerAvt,
    required this.customerPhone,
    required this.startTime,
    required this.status,
    required this.tip,
    required this.paymentMethod,
    required this.bookingServices,
    required this.totalCreditAmount,
    required this.totalCashAmount,
  });

  factory PaymentHistoryDTO.fromJson(Map<String, dynamic> json) {
    // Xử lý trường hợp bookingServices có thể là null
    List<PaymentServiceDTO> servicesList = [];
    if (json['bookingServices'] != null && json['bookingServices'] is List) {
      servicesList = (json['bookingServices'] as List)
          .map((e) => PaymentServiceDTO.fromJson(e))
          .toList();
    }

    return PaymentHistoryDTO(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      customerName: json['customerName']?.toString() ?? '',
      customerAvt: json['customerAvt']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (json['paymentMethod'] as num?)?.toInt() ?? 0,
      bookingServices: servicesList,
      totalCreditAmount: (json['totalCreditAmount'] as num?)?.toDouble() ?? 0.0,
      totalCashAmount: (json['totalCashAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  DateTime get parsedStartTime {
    try {
      return DateTime.parse(startTime).toLocal();
    } catch (e) {
      return DateTime.now(); // Fallback nếu parse lỗi
    }
  }
}

class PaymentServiceDTO {
  final int id;
  final ServiceDTO? service;
  final StaffDTO? staff;
  final double? price;
  final double? cashPrice;
  final double? finalPrice;
  final double? cashFinalPrice;
  final String? priceNote;

  PaymentServiceDTO({
    required this.id,
    this.service,
    this.staff,
    this.price,
    this.cashPrice,
    this.finalPrice,
    this.cashFinalPrice,
    this.priceNote,
  });

  factory PaymentServiceDTO.fromJson(Map<String, dynamic> json) {
    return PaymentServiceDTO(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      service: json['service'] != null ? ServiceDTO.fromJson(json['service']) : null,
      staff: json['staff'] != null ? StaffDTO.fromJson(json['staff']) : null,
      price: (json['price'] as num?)?.toDouble(),
      cashPrice: (json['cashPrice'] as num?)?.toDouble(),
      finalPrice: (json['finalPrice'] as num?)?.toDouble(),
      cashFinalPrice: (json['cashFinalPrice'] as num?)?.toDouble(),
      priceNote: json['priceNote']?.toString(),
    );
  }

  double get displayPrice => finalPrice ?? price ?? 0.0;
  double get displayCashPrice => cashFinalPrice ?? cashPrice ?? 0.0;
}

class ServiceDTO {
  final int id;
  final String name;
  final double? price;
  final String? description;
  final double? cashPrice;
  final String? avt;
  final bool plus;

  ServiceDTO({
    required this.id,
    required this.name,
    this.price,
    this.description,
    this.cashPrice,
    this.avt,
    required this.plus,
  });

  factory ServiceDTO.fromJson(Map<String, dynamic> json) {
    return ServiceDTO(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble(),
      description: json['description']?.toString(),
      cashPrice: (json['cashPrice'] as num?)?.toDouble(),
      avt: json['avt']?.toString(),
      plus: json['plus'] ?? false,
    );
  }
}

class StaffDTO {
  final int id;
  final String fullName;
  final String? avatar;

  StaffDTO({
    required this.id,
    required this.fullName,
    this.avatar,
  });

  factory StaffDTO.fromJson(Map<String, dynamic> json) {
    return StaffDTO(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      fullName: json['fullName']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
    );
  }
}