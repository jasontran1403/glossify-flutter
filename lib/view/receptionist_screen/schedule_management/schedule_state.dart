import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../api/api_service.dart';
import '../../../api/staff_schedule_model.dart';
import '../../home_screen/detail_stylist.dart';
import '../task_model.dart';

class ScheduleState {
  final int storeId;
  final VoidCallback onStateChanged;

  // Constants
  final double hourHeight = 120.0;
  final double timeColumnWidth = 90.0;
  final int startHour = 7;
  final int displayHours = 12;

  // Controllers
  final ScrollController mainScrollController = ScrollController();
  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController staffHeaderScrollController = ScrollController();

  // State variables
  DateTime selectedDate = DateTime.now();
  List<StaffSchedule> staffSchedules = [];
  Map<int, List<Task>> eventsByStaffId = {};
  bool isLoading = false;
  bool _isSyncing = false;
  String? errorMessage;

  // Booking state
  List<ServiceModel> selectedServices = [];
  int? selectedStaffIdForBooking;
  DateTime? selectedTimeForBooking;
  bool isCreatingBooking = false;

  Timer? countdownTimer;
  int remainingSeconds = 0;

  final DateFormat dateFormat = DateFormat('MMMM EEE dd, yyyy');

  ScheduleState({
    required this.storeId,
    required this.onStateChanged,
  });

  void initialize() {
    mainScrollController.addListener(_onMainScroll);

    horizontalScrollController.addListener(() {
      if (horizontalScrollController.hasClients &&
          staffHeaderScrollController.hasClients) {
        if (!_isSyncing) {
          _isSyncing = true;
          staffHeaderScrollController.jumpTo(horizontalScrollController.offset);
          _isSyncing = false;
        }
      }
    });

    staffHeaderScrollController.addListener(() {
      if (horizontalScrollController.hasClients &&
          staffHeaderScrollController.hasClients) {
        if (!_isSyncing) {
          _isSyncing = true;
          horizontalScrollController.jumpTo(staffHeaderScrollController.offset);
          _isSyncing = false;
        }
      }
    });
  }

  void _onMainScroll() {
    if (_isSyncing) return;
  }

  void dispose() {
    mainScrollController.removeListener(_onMainScroll);
    mainScrollController.dispose();
    horizontalScrollController.dispose();
    staffHeaderScrollController.dispose();
    countdownTimer?.cancel();
  }

  void setLoading(bool value) {
    isLoading = value;
    onStateChanged();
  }

  // Thay thế phần fetchSchedule trong ScheduleState của bạn

  Future<void> fetchSchedule() async {
    setLoading(true);
    errorMessage = null;

    try {
      final data = await ApiService.getAllStaffSchedule(
        storeId: storeId,
        type: 0,
        date: selectedDate,
      );

      if (data.isEmpty) {
        staffSchedules = [];
        eventsByStaffId.clear();
        errorMessage = "Không có nhân viên nào trong ngày này.";
      } else {
        Map<int, List<Task>> tempEventsByStaff = {};
        final List<Color> colors = [
          Colors.lightBlue,
          Colors.lightGreenAccent,
          Colors.cyanAccent,
          Colors.greenAccent,
          Colors.redAccent,
          Colors.amber,
        ];

        for (var schedule in data) {
          List<Task> staffEvents = [];

          final staffName = schedule.fullName ?? 'Staff ${schedule.staffId}';
          var color = colors[0];
          var statusConverted = "NEW_BOOKED";

          for (var slot in schedule.slots) {
            // Nếu là Anyone → luôn 1 màu, chỉ đổi statusConverted
            if (staffName == "Anyone") {
              color = colors[5]; // Giữ nguyên 1 màu duy nhất

              if (slot.status == 'BOOKED') {
                statusConverted = "NEW_BOOKED";
              } else if (slot.status == 'CHECKED_IN') {
                statusConverted = "CHECKED_IN";
              } else if (slot.status == 'IN_PROGRESS') {
                statusConverted = "IN_PROGRESS";
              } else if (slot.status == 'WAITING_PAYMENT') {
                statusConverted = "WAITING_PAYMENT";
              } else if (slot.status == 'PAID') {
                statusConverted = "PAID";
              } else if (slot.status == 'CANCELED') {
                statusConverted = "CANCELED";
              }
            }
            // Các staff bình thường → đổi cả màu và status
            else {
              if (slot.status == 'BOOKED') {
                color = colors[0];
                statusConverted = "NEW_BOOKED";
              } else if (slot.status == 'CHECKED_IN') {
                color = colors[1];
                statusConverted = "CHECKED_IN";
              } else if (slot.status == 'IN_PROGRESS') {
                color = colors[2];
                statusConverted = "IN_PROGRESS";
              } else if (slot.status == 'WAITING_PAYMENT') {
                color = colors[3];
                statusConverted = "WAITING_PAYMENT";
              } else if (slot.status == 'PAID') {
                color = colors[4];
                statusConverted = "PAID";
              } else if (slot.status == 'CANCELED') {
                color = colors[5];
                statusConverted = "CANCELED";
              }
            }

            // Tạo Task chỉ cho slot hợp lệ
            if (slot.status == 'BOOKED' || slot.status == 'PAST') {
              final startTime = _parseTime(slot.startTime);
              final endTime = _parseTime(slot.endTime);

              final task = Task(
                bookingId: slot.bookingId, // ← THÊM MỚI: Lấy bookingId từ slot
                markUnchange: slot.markUnchange,
                fullName: slot.fullName,
                customerAvt: slot.customerAvt,
                staffName: staffName,
                startTime: startTime,
                endTime: endTime,
                status: statusConverted,
                taskCount: slot.services,
              );

              staffEvents.add(task);
            }
          }

          tempEventsByStaff[schedule.staffId] = staffEvents;
        }

        staffSchedules = data;
        eventsByStaffId = tempEventsByStaff;
        errorMessage = null;
        remainingSeconds = 0;
        countdownTimer?.cancel();
      }
    } catch (e) {
      print('Error in fetchSchedule: $e');
      staffSchedules = [];
      eventsByStaffId.clear();
      errorMessage = "Lỗi khi lấy lịch hẹn: $e";
    } finally {
      setLoading(false);
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'am' : 'pm';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  DateTime calculateClickedTime(Offset localPosition) {
    final double clickedY = localPosition.dy;
    final double hourOffset = clickedY / hourHeight;
    final int totalMinutes = (startHour * 60) + (hourOffset * 60).floor();
    final int clickedHour = totalMinutes ~/ 60;
    final int clickedMinute = totalMinutes % 60;

    final int roundedMinute = (clickedMinute ~/ 15) * 15;

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      clickedHour,
      roundedMinute,
    );
  }

  void goToPreviousDay() {
    final today = DateTime.now();
    if (selectedDate.isAfter(today)) {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      fetchSchedule();
    }
  }

  void goToNextDay() {
    final maxDate = DateTime.now().add(const Duration(days: 14));
    if (selectedDate.isBefore(maxDate)) {
      selectedDate = selectedDate.add(const Duration(days: 1));
      fetchSchedule();
    }
  }

  void goToToday() {
    final today = DateTime.now();
    if (!selectedDate.isAtSameMomentAs(today)) {
      selectedDate = today;
      fetchSchedule();
    }
  }

  bool isTimeSlotAvailable(
      int staffId,
      DateTime date,
      TimeOfDay startTime,
      int duration,
      ) {
    final events = eventsByStaffId[staffId] ?? [];
    final startTotalMinutes = startTime.hour * 60 + startTime.minute;
    final endTotalMinutes = startTotalMinutes + duration;

    for (final event in events) {
      final eventStart = event.startTime.hour * 60 + event.startTime.minute;
      final eventEnd = event.endTime.hour * 60 + event.endTime.minute;

      if (startTotalMinutes < eventEnd && endTotalMinutes > eventStart) {
        return false;
      }
    }
    return true;
  }

  TimeOfDay calculateEndTime(TimeOfDay start, int duration) {
    int totalMinutes = start.hour * 60 + start.minute + duration;
    int endHour = (totalMinutes ~/ 60) % 24;
    int endMinute = totalMinutes % 60;
    return TimeOfDay(hour: endHour, minute: endMinute);
  }
}