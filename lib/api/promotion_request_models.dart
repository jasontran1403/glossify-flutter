// ============================================================================
// Promotion Request Models - FIXED
// ============================================================================
// Location: lib/api/models/promotion_request_models.dart
// ============================================================================

import 'package:flutter/material.dart';

// ============================================================================
// 1. PromotionRequestResponse - Main model
// ============================================================================

class PromotionRequestResponse {
  final int id;
  final UserBasicInfo user;
  final String status;
  final DateTime requestDate;
  final DateTime? approvedDate;
  final String? approvedByName;
  final DateTime? cancelledDate;
  final String? notes;
  final String? adminNotes;

  PromotionRequestResponse({
    required this.id,
    required this.user,
    required this.status,
    required this.requestDate,
    this.approvedDate,
    this.approvedByName,
    this.cancelledDate,
    this.notes,
    this.adminNotes,
  });

  factory PromotionRequestResponse.fromJson(Map<String, dynamic> json) {
    return PromotionRequestResponse(
      id: json['id'] ?? 0,
      user: UserBasicInfo.fromJson(json['user'] ?? {}),
      status: json['status'] ?? 'PENDING',
      requestDate: DateTime.parse(json['requestDate'] ?? DateTime.now().toIso8601String()),
      approvedDate: json['approvedDate'] != null
          ? DateTime.parse(json['approvedDate'])
          : null,
      approvedByName: json['approvedByName'],
      cancelledDate: json['cancelledDate'] != null
          ? DateTime.parse(json['cancelledDate'])
          : null,
      notes: json['notes'],
      adminNotes: json['adminNotes'],
    );
  }

  // Status helpers
  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  // Status color
  Color getStatusColor() {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Status icon
  IconData getStatusIcon() {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'CANCELLED':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  // Status text for display
  String getStatusText() {
    switch (status) {
      case 'PENDING':
        return 'Pending approval';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

// ============================================================================
// 2. UserBasicInfo - User info in promotion request
// ============================================================================

class UserBasicInfo {
  final int id;
  final String? avatar;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String currentRole;

  UserBasicInfo({
    required this.id,
    this.avatar,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.currentRole,
  });

  factory UserBasicInfo.fromJson(Map<String, dynamic> json) {
    return UserBasicInfo(
      id: json['id'] ?? 0,
      avatar: json['avatar'],
      fullName: json['fullName'] ?? 'Unknown',
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      currentRole: json['currentRole'] ?? 'USER',
    );
  }
}

// ============================================================================
// 3. CreatePromotionRequest - Request body for creating
// ============================================================================

class CreatePromotionRequest {
  final String? notes;

  CreatePromotionRequest({this.notes});

  Map<String, dynamic> toJson() {
    return {
      'notes': notes,
    };
  }
}

// ============================================================================
// 4. PromotionRequestSummary - Summary after action
// ============================================================================

class PromotionRequestSummary {
  final int requestId;
  final int userId;
  final String userName;
  final String oldStatus;
  final String newStatus;
  final String message;

  PromotionRequestSummary({
    required this.requestId,
    required this.userId,
    required this.userName,
    required this.oldStatus,
    required this.newStatus,
    required this.message,
  });

  factory PromotionRequestSummary.fromJson(Map<String, dynamic> json) {
    return PromotionRequestSummary(
      requestId: json['requestId'] ?? 0,
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? 'Unknown',
      oldStatus: json['oldStatus'] ?? '',
      newStatus: json['newStatus'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

// ============================================================================
// 5. ApprovePromotionRequest - Request body for approving
// ============================================================================

class ApprovePromotionRequest {
  final String? adminNotes;

  ApprovePromotionRequest({this.adminNotes});

  Map<String, dynamic> toJson() {
    return {
      'adminNotes': adminNotes,
    };
  }
}

// ============================================================================
// 6. RejectPromotionRequest - Request body for rejecting
// ============================================================================

class RejectPromotionRequest {
  final String? adminNotes;

  RejectPromotionRequest({this.adminNotes});

  Map<String, dynamic> toJson() {
    return {
      'adminNotes': adminNotes,
    };
  }
}