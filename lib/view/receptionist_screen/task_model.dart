import 'package:flutter/material.dart';
import '../../utils/constant/staff_slot.dart';

class Task {
  final int bookingId;
  final String fullName;
  final String customerAvt;
  final String? phoneNumber;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int taskCount;
  final String? staffName; // Primary staff name (backward compatible)
  final int? staffId; // ⭐ THÊM MỚI: Primary staff ID
  final String status;
  final List<ServiceItem>? serviceItems;
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

  // ⭐ NEW: Flag to mark newly added booking
  bool isNewlyAdded;

  Task({
    required this.bookingId,
    required this.fullName,
    required this.customerAvt,
    this.phoneNumber,
    required this.startTime,
    required this.endTime,
    required this.taskCount,
    this.staffName,
    this.staffId,
    required this.status,
    this.serviceItems,
    this.totalAmount,
    this.totalCashAmount,
    this.discountCode,
    this.tips,
    this.amountDiscount,
    this.paymentMethod,
    this.allStaffIds,
    this.allStaffNames,
    this.cashDiscount,
    this.reason,
    this.isNewlyAdded = false, // ⭐ NEW: Default false
  });

  // ⭐ HELPER: Check có multiple staff không
  bool get hasMultipleStaffs {
    final uniqueStaffIds = getUniqueStaffIds();
    return uniqueStaffIds.length > 1;
  }

  // ⭐ HELPER: Lấy danh sách unique staff IDs
  List<int> getUniqueStaffIds() {
    Set<int> staffIds = {};

    // Thêm từ allStaffIds nếu có
    if (allStaffIds != null && allStaffIds!.isNotEmpty) {
      staffIds.addAll(allStaffIds!);
      return staffIds.toList();
    }

    // Hoặc lấy từ staffId primary
    if (staffId != null) {
      staffIds.add(staffId!);
    }

    // Hoặc lấy từ serviceItems
    if (serviceItems != null) {
      for (var service in serviceItems!) {
        if (service.staffId != null) {
          staffIds.add(service.staffId!);
        }
      }
    }

    return staffIds.toList();
  }

  // ⭐ HELPER: Lấy danh sách unique staff names
  List<String> getUniqueStaffNames() {
    Set<String> names = {};

    // Thêm từ allStaffNames nếu có
    if (allStaffNames != null && allStaffNames!.isNotEmpty) {
      names.addAll(allStaffNames!);
      return names.toList();
    }

    // Hoặc lấy từ staffName primary
    if (staffName != null && staffName!.isNotEmpty) {
      names.add(staffName!);
    }

    // Hoặc lấy từ serviceItems
    if (serviceItems != null) {
      for (var service in serviceItems!) {
        if (service.staffName != null && service.staffName!.isNotEmpty) {
          names.add(service.staffName!);
        }
      }
    }

    return names.toList();
  }

  // ⭐ HELPER: Display text cho staff (dùng trong UI)
  String get staffDisplayText {
    final names = getUniqueStaffNames();

    if (names.isEmpty) {
      return staffName ?? 'Unknown';
    }

    if (names.length == 1) {
      return names.first;
    }

    // Multiple staff: "John +2"
    return '${names.first} +${names.length - 1}';
  }

  // ⭐ HELPER: Lấy services của 1 staff cụ thể
  List<ServiceItem> getServicesForStaff(int staffId) {
    if (serviceItems == null) return [];

    return serviceItems!
        .where((service) => service.staffId == staffId)
        .toList();
  }

  // ⭐ HELPER: Check xem staff có trong booking này không
  bool hasStaff(int staffId) {
    return getUniqueStaffIds().contains(staffId);
  }

  factory Task.fromStaffSlot(
      StaffSlot slot,
      String staffName, {
        int? staffId,
        bool isNew = false, // ⭐ NEW: Add isNew parameter
      }) {
    final startParts = slot.startTime.split(':');
    final endParts = slot.endTime.split(':');

    // ⭐ Tự động tính allStaffIds và allStaffNames từ serviceItems
    List<int>? allStaffIds;
    List<String>? allStaffNames;

    if (slot.serviceItems != null && slot.serviceItems!.isNotEmpty) {
      Set<int> staffIds = {};
      Set<String> staffNames = {};

      // Add primary staff
      if (staffId != null) {
        staffIds.add(staffId);
      }
      if (staffName.isNotEmpty) {
        staffNames.add(staffName);
      }

      // Add staff từ services
      for (var service in slot.serviceItems!) {
        if (service.staffId != null) {
          staffIds.add(service.staffId!);
        }
        if (service.staffName != null && service.staffName!.isNotEmpty) {
          staffNames.add(service.staffName!);
        }
      }

      allStaffIds = staffIds.toList();
      allStaffNames = staffNames.toList();
    }

    return Task(
      bookingId: slot.bookingId,
      fullName: slot.fullName,
      customerAvt: slot.customerAvt,
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      taskCount: slot.services,
      staffName: staffName,
      staffId: staffId,
      status: slot.status,
      serviceItems: slot.serviceItems,
      totalAmount: slot.totalAmount,
      totalCashAmount: slot.totalCashAmount,
      discountCode: slot.discountCode,
      tips: slot.tips,
      amountDiscount: slot.amountDiscount,
      paymentMethod: slot.paymentMethod,
      allStaffIds: allStaffIds,
      allStaffNames: allStaffNames,
      cashDiscount: slot.cashDiscount,
      reason: slot.reason,
      isNewlyAdded: isNew, // ⭐ NEW: Set isNewlyAdded flag
    );
  }

  @override
  String toString() {
    return 'Task{bookingId: $bookingId, fullName: $fullName, staffName: $staffName, '
        'hasMultipleStaffs: $hasMultipleStaffs, allStaffNames: ${getUniqueStaffNames()}, '
        'startTime: $startTime, endTime: $endTime, taskCount: $taskCount, '
        'status: $status, serviceItems: ${serviceItems?.length ?? 0}, '
        'isNewlyAdded: $isNewlyAdded}'; // ⭐ NEW: Add to toString
  }
}