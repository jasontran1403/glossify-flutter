import 'package:json_annotation/json_annotation.dart';

import '../../api/api_service.dart'; // Import for BookingStatus enum

part 'user_booking_models.g.dart'; // Run: flutter pub run build_runner build

// Custom JSON conversion functions for BookingStatus
BookingStatus _statusFromJson(String json) {
  return switch (json) {
    'Đã đặt' => BookingStatus.BOOKED,
    'Đang thực hiện' => BookingStatus.IN_PROGRESS,
    'Chờ thanh toán' => BookingStatus.WAITING_PAYMENT,
    'Đã thanh toán' => BookingStatus.PAID,
    'Đã hủy' => BookingStatus.CANCELED,
    _ => throw Exception('Unknown status: $json'),
  };
}

String _statusToJson(BookingStatus status) => status.name;

@JsonSerializable()
class UserBookingList {
  @JsonKey(name: 'id')
  final int id;
  @JsonKey(name: 'customerName')
  final String customerName;
  @JsonKey(name: 'customerPhone')
  final String customerPhone;
  final String location;
  @JsonKey(name: 'status', fromJson: _statusFromJson, toJson: _statusToJson)
  final BookingStatus status;
  @JsonKey(name: 'startTime')
  final DateTime startTime;
  @JsonKey(name: 'endTime')
  final DateTime endTime;
  @JsonKey(name: 'totalAmount')
  final double totalAmount;
  @JsonKey(name: 'serviceCount')
  final int serviceCount;
  @JsonKey(name: 'canCancel')
  final bool canCancel;
  final Staff? staff;
  @JsonKey(name: 'paymentMethod')
  final int paymentMethod;
  @JsonKey(name: 'giftCardAmount')
  final double? giftCardAmount;
  @JsonKey(name: 'hasDiscount')
  final bool hasDiscount;
  @JsonKey(name: 'hasGiftCard')
  final bool hasGiftCard;
  @JsonKey(name: 'cancelReason')
  final String? cancelReason;
  @JsonKey(name: 'cancelledAt')
  final DateTime? cancelledAt;

  UserBookingList({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.location,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.totalAmount,
    required this.serviceCount,
    required this.canCancel,
    this.staff,
    required this.paymentMethod,
    this.giftCardAmount,
    required this.hasDiscount,
    required this.hasGiftCard,
    this.cancelReason,
    this.cancelledAt,
  });

  factory UserBookingList.fromJson(Map<String, dynamic> json) =>
      _$UserBookingListFromJson(json);
  Map<String, dynamic> toJson() => _$UserBookingListToJson(this);
}

@JsonSerializable()
class Staff {
  final int id;
  @JsonKey(name: 'fullName')
  final String fullName;
  final String avatar;
  final double rating;

  Staff({
    required this.id,
    required this.fullName,
    required this.avatar,
    required this.rating,
  });

  factory Staff.fromJson(Map<String, dynamic> json) => _$StaffFromJson(json);
  Map<String, dynamic> toJson() => _$StaffToJson(this);
}

@JsonSerializable()
class UserBookingDetail {
  final int id;
  @JsonKey(name: 'customerName')
  final String customerName;
  @JsonKey(name: 'customerPhone')
  final String customerPhone;
  final String location;
  @JsonKey(name: 'status', fromJson: _statusFromJson, toJson: _statusToJson)
  final BookingStatus status;
  @JsonKey(name: 'startTime')
  final DateTime startTime;
  @JsonKey(name: 'endTime')
  final DateTime endTime;
  final Staff staff;
  @JsonKey(name: 'services')
  final List<UserBookingService> services;
  @JsonKey(name: 'serviceCount')
  final int serviceCount;
  @JsonKey(name: 'paymentBreakdown')
  final PaymentBreakdown paymentBreakdown;
  @JsonKey(name: 'discountInfo')
  final DiscountInfo? discountInfo;
  @JsonKey(name: 'giftCardUsages')
  final List<GiftCardUsage>? giftCardUsages;
  @JsonKey(name: 'cancelReason')
  final String? cancelReason;
  @JsonKey(name: 'cancelledAt')
  final DateTime? cancelledAt;

  UserBookingDetail({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.location,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.staff,
    required this.services,
    required this.serviceCount,
    required this.paymentBreakdown,
    this.discountInfo,
    this.giftCardUsages,
    this.cancelReason,
    this.cancelledAt,
  });

  factory UserBookingDetail.fromJson(Map<String, dynamic> json) =>
      _$UserBookingDetailFromJson(json);
  Map<String, dynamic> toJson() => _$UserBookingDetailToJson(this);
}

@JsonSerializable()
class UserBookingService {
  @JsonKey(name: 'id')
  final int id;
  @JsonKey(name: 'serviceName')
  final String name;  // Maps 'serviceName' → 'name' for your existing code
  @JsonKey(name: 'staffName')
  final String staffName;
  @JsonKey(name: 'price')
  final double price;
  @JsonKey(name: 'finalPrice')
  final double finalPrice;
  @JsonKey(name: 'priceNote')
  final String? priceNote;  // Nullable to handle null safely

  UserBookingService({
    required this.id,
    required this.name,
    required this.staffName,
    required this.price,
    required this.finalPrice,
    this.priceNote,
  });

  factory UserBookingService.fromJson(Map<String, dynamic> json) => _$UserBookingServiceFromJson(json);
  Map<String, dynamic> toJson() => _$UserBookingServiceToJson(this);
}

@JsonSerializable()
class PaymentBreakdown {
  final double subtotal;
  final double tip;
  @JsonKey(name: 'totalAmount')
  final double totalAmount;
  @JsonKey(name: 'paymentMethod')
  final int paymentMethod;
  @JsonKey(name: 'cashPaidAmount')
  final double cashPaidAmount;
  @JsonKey(name: 'creditAmount')
  final double creditAmount;
  @JsonKey(name: 'chequeAmount')
  final double chequeAmount;
  @JsonKey(name: 'othersAmount')
  final double othersAmount;
  @JsonKey(name: 'giftCardAmount')
  final double giftCardAmount;
  @JsonKey(name: 'changeAmount')
  final double changeAmount;

  PaymentBreakdown({
    required this.subtotal,
    required this.tip,
    required this.totalAmount,
    required this.paymentMethod,
    required this.cashPaidAmount,
    required this.creditAmount,
    required this.chequeAmount,
    required this.othersAmount,
    required this.giftCardAmount,
    required this.changeAmount,
  });

  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) =>
      _$PaymentBreakdownFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentBreakdownToJson(this);
}

@JsonSerializable()
class DiscountInfo {
  @JsonKey(name: 'discountCodeId')
  final int discountCodeId;
  final String code;
  @JsonKey(name: 'discountValue')
  final String discountValue;
  @JsonKey(name: 'amountBeforeDiscount')
  final double amountBeforeDiscount;
  @JsonKey(name: 'discountAmount')
  final double discountAmount;
  @JsonKey(name: 'amountAfterDiscount')
  final double amountAfterDiscount;

  DiscountInfo({
    required this.discountCodeId,
    required this.code,
    required this.discountValue,
    required this.amountBeforeDiscount,
    required this.discountAmount,
    required this.amountAfterDiscount,
  });

  factory DiscountInfo.fromJson(Map<String, dynamic> json) =>
      _$DiscountInfoFromJson(json);
  Map<String, dynamic> toJson() => _$DiscountInfoToJson(this);
}

@JsonSerializable()
class GiftCardUsage {
  final int id;
  @JsonKey(name: 'cardCode')
  final String cardCode;
  @JsonKey(name: 'deductedAmount')
  final double deductedAmount;
  @JsonKey(name: 'remainingBalance')
  final double remainingBalance;

  GiftCardUsage({
    required this.id,
    required this.cardCode,
    required this.deductedAmount,
    required this.remainingBalance,
  });

  factory GiftCardUsage.fromJson(Map<String, dynamic> json) =>
      _$GiftCardUsageFromJson(json);
  Map<String, dynamic> toJson() => _$GiftCardUsageToJson(this);
}

@JsonSerializable()
class UserCancelBookingResponse {
  final bool success;
  final String message;
  @JsonKey(name: 'bookingId')
  final int bookingId;

  UserCancelBookingResponse({
    required this.success,
    required this.message,
    required this.bookingId,
  });

  factory UserCancelBookingResponse.fromJson(Map<String, dynamic> json) =>
      _$UserCancelBookingResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UserCancelBookingResponseToJson(this);
}
