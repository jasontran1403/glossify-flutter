// ⭐ Cập nhật trong staff_slot.dart
class StaffSlot {
  final int bookingId;
  final bool markUnchange;
  final String fullName;
  final String customerAvt;
  final String startTime;
  final String endTime;
  final int services;
  final List<ServiceItem>? serviceItems;
  final String status;
  final double? totalAmount;
  final double? totalCashAmount;
  final String? discountCode;
  final double? tips;
  final double? amountDiscount;
  final String? paymentMethod;
  final double? cashDiscount;
  final String? reason;

  // ⭐ THÊM MỚI: Multiple staff support
  final List<int>? allStaffIds;
  final List<String>? allStaffNames;

  StaffSlot({
    required this.bookingId,
    required this.markUnchange,
    required this.fullName,
    required this.customerAvt,
    required this.startTime,
    required this.endTime,
    required this.services,
    this.serviceItems,
    required this.status,
    this.totalAmount,
    this.totalCashAmount,
    this.discountCode,
    this.tips,
    this.amountDiscount,
    this.paymentMethod,
    this.allStaffIds,
    this.allStaffNames,
    this.cashDiscount,
    this.reason
  });

  factory StaffSlot.fromJson(Map<String, dynamic> json) {
    return StaffSlot(
      bookingId: json['bookingId'],
      markUnchange: json['markUnchange'],
      fullName: json['fullName'],
      customerAvt: json['customerAvt'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      services: json['services'],
      serviceItems: json['serviceItems'] != null
          ? (json['serviceItems'] as List)
          .map((item) => ServiceItem.fromJson(item))
          .toList()
          : null,
      status: json['status'],
      totalAmount: json['totalAmount']?.toDouble(),
      totalCashAmount: json['totalCashAmount']?.toDouble(),
      discountCode: json['discountCode'],
      cashDiscount: json['cashDiscount'],
      tips: json['tips']?.toDouble(),
      amountDiscount: json['amountDiscount']?.toDouble(),
      paymentMethod: json['paymentMethod'],
      reason: json['reason'],
      // ⭐ Parse multiple staff info (optional - backward compatible)
      allStaffIds: json['allStaffIds'] != null
          ? List<int>.from(json['allStaffIds'])
          : null,
      allStaffNames: json['allStaffNames'] != null
          ? List<String>.from(json['allStaffNames'])
          : null,
    );
  }
}

// ⭐ Cập nhật ServiceItem để có staff info
class ServiceItem {
  final int? bookingServiceId; // ⭐ THÊM MỚI
  final int? serviceId; // ⭐ THÊM MỚI
  final String name;
  final double price;

  // ⭐ THÊM MỚI: Staff info
  final int? staffId;
  final String? staffName;
  final int? duration;

  ServiceItem({
    this.bookingServiceId,
    this.serviceId,
    required this.name,
    required this.price,
    this.staffId,
    this.staffName,
    this.duration,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      bookingServiceId: json['bookingServiceId'],
      serviceId: json['serviceId'],
      name: json['name'] ?? 'Unknown Service',
      price: json['price']?.toDouble() ?? 0.0,
      // ⭐ Optional fields - backward compatible
      staffId: json['staffId'],
      staffName: json['staffName'],
      duration: json['duration'],
    );
  }

  @override
  String toString() {
    return 'ServiceItem{name: $name, price: $price, staffName: $staffName}';
  }
}