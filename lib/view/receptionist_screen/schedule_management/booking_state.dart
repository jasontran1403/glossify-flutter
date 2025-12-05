import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../api/api_service.dart';
import '../../../api/staff_schedule_model.dart';
import '../../home_screen/detail_stylist.dart';
import '../task_model.dart';

class BookingState {
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

  // ⭐ THÊM GETTER TASKS - Flatten tất cả tasks từ eventsByStaffId
  List<Task> get tasks {
    List<Task> allTasks = [];
    eventsByStaffId.forEach((staffId, taskList) {
      allTasks.addAll(taskList);
    });
    return allTasks;
  }

  BookingState({
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

  // ⭐ FIXED: Sử dụng cùng API với fetchSchedule nhưng merge thông minh
  Future<void> fetchScheduleIncremental() async {
    try {
      // ⭐ Lấy danh sách booking IDs hiện tại TRƯỚC KHI GỌI API
      final currentBookingIds = tasks.map((t) => t.bookingId).toSet();

      // ⭐ GỌI API GIỐNG fetchSchedule()
      final data = await ApiService.getAllStaffSchedule(
        storeId: storeId,
        type: 1,
        date: selectedDate,
      );

      if (data.isEmpty) {
        // Không có dữ liệu mới
        return;
      }

      // ⭐ Parse new data và tìm booking mới
      List<Task> newTasks = [];
      Map<int, List<Task>> newEventsByStaff = {};

      for (var schedule in data) {
        final staffName = schedule.fullName ?? 'Staff ${schedule.staffId}';
        final staffId = schedule.staffId;

        List<Task> newStaffTasks = [];

        for (var slot in schedule.slots) {
          final bookingId = slot.bookingId;

          // ⭐ KIỂM TRA: Nếu booking đã tồn tại, BỎ QUA
          if (currentBookingIds.contains(bookingId)) {
            continue;
          }

          // ⭐ BOOKING MỚI: Đánh dấu isNew = true
          final task = Task.fromStaffSlot(
            slot,
            staffName,
            staffId: staffId,
            isNew: true, // ⭐ ĐÁNH DẤU LÀ BOOKING MỚI
          );

          newTasks.add(task);
          newStaffTasks.add(task);
        }

        // Nếu có task mới cho staff này
        if (newStaffTasks.isNotEmpty) {
          newEventsByStaff[staffId] = newStaffTasks;
        }
      }

      // ⭐ CHỈ THÊM CÁC BOOKING MỚI VÀO LIST HIỆN TẠI
      if (newTasks.isNotEmpty) {
        print('✅ Found ${newTasks.length} new booking(s)');

        // Merge events by staff
        newEventsByStaff.forEach((staffId, newStaffTasks) {
          if (eventsByStaffId.containsKey(staffId)) {
            // Staff đã có booking → thêm vào list hiện tại
            eventsByStaffId[staffId]!.addAll(newStaffTasks);
          } else {
            // Staff chưa có booking → tạo list mới
            eventsByStaffId[staffId] = newStaffTasks;
          }
        });

        // ⭐ CẬP NHẬT staffSchedules nếu có staff mới
        for (var schedule in data) {
          final staffId = schedule.staffId;
          final exists = staffSchedules.any((s) => s.staffId == staffId);

          if (!exists && newEventsByStaff.containsKey(staffId)) {
            // Thêm staff mới vào list
            staffSchedules.add(schedule);
          }
        }

        // Trigger UI update
        onStateChanged();

        // ⭐ TỰ ĐỘNG XÓA HIGHLIGHT SAU 30 GIÂY
        Future.delayed(const Duration(seconds: 30), () {
          for (var task in newTasks) {
            task.isNewlyAdded = false;
          }
          onStateChanged();
        });
      } else {
        print('ℹ️ No new bookings found');
      }
    } catch (e) {
      print('❌ Error fetching incremental schedule: $e');
    }
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

  Future<void> fetchSchedule() async {
    setLoading(true);
    errorMessage = null;

    try {
      final data = await ApiService.getAllStaffSchedule(
        storeId: storeId,
        type: 1,
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
          final staffId = schedule.staffId;

          for (var slot in schedule.slots) {
            final task = Task.fromStaffSlot(
              slot,
              staffName,
              staffId: staffId,
              isNew: false, // ⭐ fetchSchedule không đánh dấu isNew
            );

            staffEvents.add(task);
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

  String getFormattedDate() {
    return DateFormat('MMM dd, yyyy').format(selectedDate);
  }

  void previousDay() => goToPreviousDay();

  void nextDay() => goToNextDay();

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

  Future<void> selectDate(BuildContext context) async {
    final today = DateTime.now();
    final maxDate = today.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: today,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      selectedDate = picked;
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