import 'package:flutter/material.dart';

class DayOffModel {
  final int id;
  final int staffId;
  final String? staffName;
  final String dayOffType;
  final String recurrenceType;
  final DateTime? specificDate;
  final DateTime? startDate;  // ✅ NEW for DATE_RANGE
  final DateTime? endDate;    // ✅ NEW for DATE_RANGE
  final int? dayOfWeek;
  final String? dayOfWeekName;
  final int? dayOfMonth;
  final String? startTime;
  final String? endTime;
  final String status;
  final String? staffNote;
  final String? adminNote;
  final DateTime? createdAt;

  DayOffModel({
    required this.id,
    required this.staffId,
    this.staffName,
    required this.dayOffType,
    required this.recurrenceType,
    this.specificDate,
    this.startDate,  // ✅ NEW
    this.endDate,    // ✅ NEW
    this.dayOfWeek,
    this.dayOfWeekName,
    this.dayOfMonth,
    this.startTime,
    this.endTime,
    required this.status,
    this.staffNote,
    this.adminNote,
    this.createdAt,
  });

  factory DayOffModel.fromJson(Map<String, dynamic> json) {
    return DayOffModel(
      id: json['id'],
      staffId: json['staffId'],
      staffName: json['staffName'],
      dayOffType: json['dayOffType'],
      recurrenceType: json['recurrenceType'],
      specificDate: json['specificDate'] != null
          ? DateTime.parse(json['specificDate'])
          : null,
      startDate: json['startDate'] != null  // ✅ NEW
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null      // ✅ NEW
          ? DateTime.parse(json['endDate'])
          : null,
      dayOfWeek: json['dayOfWeek'],
      dayOfWeekName: json['dayOfWeekName'],
      dayOfMonth: json['dayOfMonth'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      status: json['status'],
      staffNote: json['staffNote'],
      adminNote: json['adminNote'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  bool get isFullDay => dayOffType == 'FULL_DAY';

  String get timeRangeString {
    if (isFullDay) return 'Full Day';
    if (startTime != null && endTime != null) {
      return '$startTime - $endTime';
    }
    return '';
  }

  String get recurrenceDescription {
    switch (recurrenceType) {
      case 'ONCE':
        if (specificDate != null) {
          return 'On ${_formatDate(specificDate!)}';
        }
        return 'One time';
      case 'DATE_RANGE':  // ✅ NEW
        if (startDate != null && endDate != null) {
          return '${_formatDate(startDate!)} - ${_formatDate(endDate!)}';
        }
        return 'Date range';
      case 'DAILY':
        return 'Every day';
      case 'WEEKLY':
        return 'Every $dayOfWeekName';
      case 'MONTHLY':
        return 'Day $dayOfMonth of every month';
      default:
        return recurrenceType;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Color getStatusColor() {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'ACTIVE':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELED':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }
}
