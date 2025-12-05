// lib/models/giftcard_model.dart (as provided - no changes needed)
import 'dart:ui';

import 'package:flutter/material.dart';

class Giftcard {
  final String code;
  String owner;
  double initialValue;
  double remainingValue;
  DateTime activationDate;
  GiftcardStatus status;

  Giftcard({
    required this.code,
    required this.owner,
    required this.initialValue,
    required this.remainingValue,
    required this.activationDate,
    required this.status,
  });

  Giftcard copyWith({
    String? owner,
    double? initialValue,
    double? remainingValue,
    DateTime? activationDate,
    GiftcardStatus? status,
  }) {
    return Giftcard(
      code: code,
      owner: owner ?? this.owner,
      initialValue: initialValue ?? this.initialValue,
      remainingValue: remainingValue ?? this.remainingValue,
      activationDate: activationDate ?? this.activationDate,
      status: status ?? this.status,
    );
  }

  // Added fromJson for API compatibility (map backend status to frontend enum)
  factory Giftcard.fromJson(Map<String, dynamic> json) {
    return Giftcard(
      code: json['code'] ?? '',
      owner: json['ownerName'] ?? json['owner'] ?? '', // Assume backend sends ownerName or owner
      initialValue: (json['initialValue'] ?? 0.0).toDouble(),
      remainingValue: (json['remainingBalance'] ?? 0.0).toDouble(),
      activationDate: DateTime.parse(json['creationDate'] ?? DateTime.now().toIso8601String()),
      status: _mapBackendStatusToFrontend(json['status'] ?? 'ACTIVE'),
    );
  }

  static GiftcardStatus _mapBackendStatusToFrontend(String backendStatus) {
    switch (backendStatus.toUpperCase()) {
      case 'ACTIVE':
        return GiftcardStatus.activated;
      case 'EXPIRED':
      case 'DEACTIVATED':
        return GiftcardStatus.suspend;
      default:
        return GiftcardStatus.inactive;
    }
  }
}

enum GiftcardStatus {
  inactive,
  activated,
  suspend,
}

extension GiftcardStatusExtension on GiftcardStatus {
  String get name {
    switch (this) {
      case GiftcardStatus.inactive:
        return 'IN_ACTIVE';
      case GiftcardStatus.activated:
        return 'ACTIVATED';
      case GiftcardStatus.suspend:
        return 'SUSPENDED';
    }
  }

  Color get color {
    switch (this) {
      case GiftcardStatus.inactive:
        return Colors.orange;
      case GiftcardStatus.activated:
        return Colors.green;
      case GiftcardStatus.suspend:
        return Colors.red;
    }
  }
}