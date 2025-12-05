// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_booking_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserBookingList _$UserBookingListFromJson(Map<String, dynamic> json) =>
    UserBookingList(
      id: (json['id'] as num).toInt(),
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      location: json['location'] as String,
      status: _statusFromJson(json['status'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      serviceCount: (json['serviceCount'] as num).toInt(),
      canCancel: json['canCancel'] as bool,
      staff:
          json['staff'] == null
              ? null
              : Staff.fromJson(json['staff'] as Map<String, dynamic>),
      paymentMethod: (json['paymentMethod'] as num).toInt(),
      giftCardAmount: (json['giftCardAmount'] as num?)?.toDouble(),
      hasDiscount: json['hasDiscount'] as bool,
      hasGiftCard: json['hasGiftCard'] as bool,
      cancelReason: json['cancelReason'] as String?,
      cancelledAt:
          json['cancelledAt'] == null
              ? null
              : DateTime.parse(json['cancelledAt'] as String),
    );

Map<String, dynamic> _$UserBookingListToJson(UserBookingList instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'location': instance.location,
      'status': _statusToJson(instance.status),
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'totalAmount': instance.totalAmount,
      'serviceCount': instance.serviceCount,
      'canCancel': instance.canCancel,
      'staff': instance.staff,
      'paymentMethod': instance.paymentMethod,
      'giftCardAmount': instance.giftCardAmount,
      'hasDiscount': instance.hasDiscount,
      'hasGiftCard': instance.hasGiftCard,
      'cancelReason': instance.cancelReason,
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
    };

Staff _$StaffFromJson(Map<String, dynamic> json) => Staff(
  id: (json['id'] as num).toInt(),
  fullName: json['fullName'] as String,
  avatar: json['avatar'] as String,
  rating: (json['rating'] as num).toDouble(),
);

Map<String, dynamic> _$StaffToJson(Staff instance) => <String, dynamic>{
  'id': instance.id,
  'fullName': instance.fullName,
  'avatar': instance.avatar,
  'rating': instance.rating,
};

UserBookingDetail _$UserBookingDetailFromJson(
  Map<String, dynamic> json,
) => UserBookingDetail(
  id: (json['id'] as num).toInt(),
  customerName: json['customerName'] as String,
  customerPhone: json['customerPhone'] as String,
  location: json['location'] as String,
  status: _statusFromJson(json['status'] as String),
  startTime: DateTime.parse(json['startTime'] as String),
  endTime: DateTime.parse(json['endTime'] as String),
  staff: Staff.fromJson(json['staff'] as Map<String, dynamic>),
  services:
      (json['services'] as List<dynamic>)
          .map((e) => UserBookingService.fromJson(e as Map<String, dynamic>))
          .toList(),
  serviceCount: (json['serviceCount'] as num).toInt(),
  paymentBreakdown: PaymentBreakdown.fromJson(
    json['paymentBreakdown'] as Map<String, dynamic>,
  ),
  discountInfo:
      json['discountInfo'] == null
          ? null
          : DiscountInfo.fromJson(json['discountInfo'] as Map<String, dynamic>),
  giftCardUsages:
      (json['giftCardUsages'] as List<dynamic>?)
          ?.map((e) => GiftCardUsage.fromJson(e as Map<String, dynamic>))
          .toList(),
  cancelReason: json['cancelReason'] as String?,
  cancelledAt:
      json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
);

Map<String, dynamic> _$UserBookingDetailToJson(UserBookingDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'location': instance.location,
      'status': _statusToJson(instance.status),
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'staff': instance.staff,
      'services': instance.services,
      'serviceCount': instance.serviceCount,
      'paymentBreakdown': instance.paymentBreakdown,
      'discountInfo': instance.discountInfo,
      'giftCardUsages': instance.giftCardUsages,
      'cancelReason': instance.cancelReason,
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
    };

UserBookingService _$UserBookingServiceFromJson(Map<String, dynamic> json) =>
    UserBookingService(
      id: (json['id'] as num).toInt(),
      name: json['serviceName'] as String,
      staffName: json['staffName'] as String,
      price: (json['price'] as num).toDouble(),
      finalPrice: (json['finalPrice'] as num).toDouble(),
      priceNote: json['priceNote'] as String?,
    );

Map<String, dynamic> _$UserBookingServiceToJson(UserBookingService instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serviceName': instance.name,
      'staffName': instance.staffName,
      'price': instance.price,
      'finalPrice': instance.finalPrice,
      'priceNote': instance.priceNote,
    };

PaymentBreakdown _$PaymentBreakdownFromJson(Map<String, dynamic> json) =>
    PaymentBreakdown(
      subtotal: (json['subtotal'] as num).toDouble(),
      tip: (json['tip'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      paymentMethod: (json['paymentMethod'] as num).toInt(),
      cashPaidAmount: (json['cashPaidAmount'] as num).toDouble(),
      creditAmount: (json['creditAmount'] as num).toDouble(),
      chequeAmount: (json['chequeAmount'] as num).toDouble(),
      othersAmount: (json['othersAmount'] as num).toDouble(),
      giftCardAmount: (json['giftCardAmount'] as num).toDouble(),
      changeAmount: (json['changeAmount'] as num).toDouble(),
    );

Map<String, dynamic> _$PaymentBreakdownToJson(PaymentBreakdown instance) =>
    <String, dynamic>{
      'subtotal': instance.subtotal,
      'tip': instance.tip,
      'totalAmount': instance.totalAmount,
      'paymentMethod': instance.paymentMethod,
      'cashPaidAmount': instance.cashPaidAmount,
      'creditAmount': instance.creditAmount,
      'chequeAmount': instance.chequeAmount,
      'othersAmount': instance.othersAmount,
      'giftCardAmount': instance.giftCardAmount,
      'changeAmount': instance.changeAmount,
    };

DiscountInfo _$DiscountInfoFromJson(Map<String, dynamic> json) => DiscountInfo(
  discountCodeId: (json['discountCodeId'] as num).toInt(),
  code: json['code'] as String,
  discountValue: json['discountValue'] as String,
  amountBeforeDiscount: (json['amountBeforeDiscount'] as num).toDouble(),
  discountAmount: (json['discountAmount'] as num).toDouble(),
  amountAfterDiscount: (json['amountAfterDiscount'] as num).toDouble(),
);

Map<String, dynamic> _$DiscountInfoToJson(DiscountInfo instance) =>
    <String, dynamic>{
      'discountCodeId': instance.discountCodeId,
      'code': instance.code,
      'discountValue': instance.discountValue,
      'amountBeforeDiscount': instance.amountBeforeDiscount,
      'discountAmount': instance.discountAmount,
      'amountAfterDiscount': instance.amountAfterDiscount,
    };

GiftCardUsage _$GiftCardUsageFromJson(Map<String, dynamic> json) =>
    GiftCardUsage(
      id: (json['id'] as num).toInt(),
      cardCode: json['cardCode'] as String,
      deductedAmount: (json['deductedAmount'] as num).toDouble(),
      remainingBalance: (json['remainingBalance'] as num).toDouble(),
    );

Map<String, dynamic> _$GiftCardUsageToJson(GiftCardUsage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'cardCode': instance.cardCode,
      'deductedAmount': instance.deductedAmount,
      'remainingBalance': instance.remainingBalance,
    };

UserCancelBookingResponse _$UserCancelBookingResponseFromJson(
  Map<String, dynamic> json,
) => UserCancelBookingResponse(
  success: json['success'] as bool,
  message: json['message'] as String,
  bookingId: (json['bookingId'] as num).toInt(),
);

Map<String, dynamic> _$UserCancelBookingResponseToJson(
  UserCancelBookingResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'message': instance.message,
  'bookingId': instance.bookingId,
};
