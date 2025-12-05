// Add this new model in a separate file or same as StaffSlot
import '../utils/constant/staff_slot.dart';

class StaffSchedule {
  final int staffId;
  final String fullName; // Staff name
  final String avatar;
  final List<StaffSlot> slots; // Booked slots with customer info

  StaffSchedule({
    required this.staffId,
    required this.fullName,
    required this.avatar,
    required this.slots,
  });

  factory StaffSchedule.fromJson(Map<String, dynamic> json) {
    return StaffSchedule(
      staffId: json['staffId'],
      fullName: json['fullName'],
      avatar: json['avatar'],
      slots: (json['slots'] as List<dynamic>)
          .map((e) => StaffSlot.fromJson(e))
          .toList(),
    );
  }
}