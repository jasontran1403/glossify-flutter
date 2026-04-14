import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
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
  DateTime selectedDate = _getChicagoToday();
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

  // ⭐ Helper: Get Chicago today
  static DateTime _getChicagoToday() {
    final chicago = tz.getLocation('America/Chicago');
    final now = tz.TZDateTime.now(chicago);
    return DateTime(now.year, now.month, now.day);
  }

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
      // ⭐ DEFINE STATUS GROUPS FOR TABS
      final activeStatuses = {'BOOKED', 'NEW_BOOKED', 'CHECKED_IN', 'IN_PROGRESS', 'REQUEST_MORE_STAFF'};
      final pendingStatuses = {'WAITING_PAYMENT'};
      final doneStatuses = {'PAID'};
      final canceledStatuses = {'CANCELED'};

      // Helper function to get tab group
      String? getTabGroup(String status) {
        if (activeStatuses.contains(status)) return 'ACTIVE';
        if (pendingStatuses.contains(status)) return 'PENDING';
        if (doneStatuses.contains(status)) return 'DONE';
        if (canceledStatuses.contains(status)) return 'CANCELED';
        return null;
      }

      // ⭐ LƯU CẢ BOOKING IDS VÀ STATUS MAP
      final currentBookingIds = tasks.map((t) => t.bookingId).toSet();
      final Map<int, String> currentBookingStatuses = {};

      for (var task in tasks) {
        currentBookingStatuses[task.bookingId] = task.status;
      }

      final data = await ApiService.getAllStaffSchedule(
        storeId: storeId,
        type: 1,
        date: selectedDate,
      );

      if (data.isEmpty) {
        return;
      }

      // ⭐ ANALYZE: New bookings, tab changed, status changed (same tab), removed
      List<Task> newTasks = [];
      List<Task> tabChangedTasks = []; // ⭐ Chuyển TAB → cần highlight
      List<Task> sameTabStatusChangedTasks = []; // ⭐ Cùng TAB → không highlight
      Set<int> apiBookingIds = {};

      for (var schedule in data) {
        final staffName = schedule.fullName ?? 'Staff ${schedule.staffId}';
        final staffId = schedule.staffId;

        for (var slot in schedule.slots) {
          final bookingId = slot.bookingId;
          final newStatus = slot.status;

          apiBookingIds.add(bookingId);

          // ⭐ CASE 1: BOOKING MỚI (chưa có trong memory)
          if (!currentBookingIds.contains(bookingId)) {
            final task = Task.fromStaffSlot(
              slot,
              staffName,
              staffId: staffId,
              isNew: true, // ⭐ ĐÁNH DẤU MỚI
            );
            newTasks.add(task);
            continue;
          }

          // ⭐ CASE 2: STATUS THAY ĐỔI
          final oldStatus = currentBookingStatuses[bookingId];
          if (oldStatus != newStatus) {
            final oldTabGroup = getTabGroup(oldStatus!);
            final newTabGroup = getTabGroup(newStatus);

            // ⭐ CHECK: Có chuyển TAB không?
            if (oldTabGroup != newTabGroup) {
              final task = Task.fromStaffSlot(
                slot,
                staffName,
                staffId: staffId,
                isNew: true, // ⭐ ĐÁNH DẤU ĐỂ HIGHLIGHT
              );
              tabChangedTasks.add(task);
            } else {
              final task = Task.fromStaffSlot(
                slot,
                staffName,
                staffId: staffId,
                isNew: false, // ⭐ KHÔNG HIGHLIGHT
              );
              sameTabStatusChangedTasks.add(task);
            }
            continue;
          }
        }
      }

      // ⭐ DETECT REMOVED BOOKINGS (có trong memory nhưng không có trong API)
      final removedBookingIds = currentBookingIds.difference(apiBookingIds);

      // ⭐ CẬP NHẬT MEMORY
      bool hasChanges = false;

      // ⭐ XÓA BOOKINGS KHÔNG CÒN TRONG API
      if (removedBookingIds.isNotEmpty) {
        eventsByStaffId.forEach((staffId, taskList) {
          taskList.removeWhere((task) {
            if (removedBookingIds.contains(task.bookingId)) {
              return true;
            }
            return false;
          });
        });
        hasChanges = true;
      }

      // ⭐ UPDATE TAB-CHANGED BOOKINGS (with highlight)
      if (tabChangedTasks.isNotEmpty) {
        for (var updatedTask in tabChangedTasks) {
          // Tìm và xóa booking cũ
          eventsByStaffId.forEach((staffId, taskList) {
            taskList.removeWhere((task) {
              if (task.bookingId == updatedTask.bookingId) {
                return true;
              }
              return false;
            });
          });

          // Thêm booking mới với status mới
          final staffId = updatedTask.staffId ?? 0;
          if (eventsByStaffId.containsKey(staffId)) {
            eventsByStaffId[staffId]!.add(updatedTask);
          } else {
            eventsByStaffId[staffId] = [updatedTask];
          }
        }
        hasChanges = true;
      }

      // ⭐ UPDATE SAME-TAB STATUS CHANGED BOOKINGS (without highlight)
      if (sameTabStatusChangedTasks.isNotEmpty) {
        for (var updatedTask in sameTabStatusChangedTasks) {
          // Tìm và xóa booking cũ
          eventsByStaffId.forEach((staffId, taskList) {
            taskList.removeWhere((task) {
              if (task.bookingId == updatedTask.bookingId) {
                return true;
              }
              return false;
            });
          });

          // Thêm booking mới với status mới
          final staffId = updatedTask.staffId ?? 0;
          if (eventsByStaffId.containsKey(staffId)) {
            eventsByStaffId[staffId]!.add(updatedTask);
          } else {
            eventsByStaffId[staffId] = [updatedTask];
          }
        }
        hasChanges = true;
      }

      // ⭐ ADD NEW BOOKINGS
      if (newTasks.isNotEmpty) {
        // Group by staff
        Map<int, List<Task>> newEventsByStaff = {};
        for (var task in newTasks) {
          final staffId = task.staffId ?? 0;
          if (!newEventsByStaff.containsKey(staffId)) {
            newEventsByStaff[staffId] = [];
          }
          newEventsByStaff[staffId]!.add(task);
        }

        // Merge
        newEventsByStaff.forEach((staffId, newStaffTasks) {
          if (eventsByStaffId.containsKey(staffId)) {
            eventsByStaffId[staffId]!.addAll(newStaffTasks);
          } else {
            eventsByStaffId[staffId] = newStaffTasks;
          }
        });

        // Update staffSchedules nếu cần
        for (var schedule in data) {
          final staffId = schedule.staffId;
          final exists = staffSchedules.any((s) => s.staffId == staffId);
          if (!exists && newEventsByStaff.containsKey(staffId)) {
            staffSchedules.add(schedule);
          }
        }
        hasChanges = true;
      }

      if (hasChanges) {
        onStateChanged();

        final highlightedTasks = [...newTasks, ...tabChangedTasks];
        if (highlightedTasks.isNotEmpty) {
          Future.delayed(const Duration(seconds: 30), () {
            for (var task in highlightedTasks) {
              task.isNewlyAdded = false;
            }
            onStateChanged();
          });
        }
      }
    } catch (e) {
      print('\n❌ ERROR in fetchScheduleIncremental: $e');
      print('Stack trace: ${StackTrace.current}');
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

  // ⭐ Previous day with Chicago timezone constraint
  void goToPreviousDay() {
    final chicago = tz.getLocation('America/Chicago');
    final today = tz.TZDateTime.now(chicago);
    final todayDate = DateTime(today.year, today.month, today.day);

    if (selectedDate.isAfter(todayDate)) {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      fetchSchedule();
    }
  }

  // ⭐ Next day with Chicago timezone constraint
  void goToNextDay() {
    final chicago = tz.getLocation('America/Chicago');
    final today = tz.TZDateTime.now(chicago);
    final maxDate = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 14));

    if (selectedDate.isBefore(maxDate)) {
      selectedDate = selectedDate.add(const Duration(days: 1));
      fetchSchedule();
    }
  }

  // ⭐ Date picker with Chicago timezone constraints
  Future<void> selectDate(BuildContext context) async {
    final chicago = tz.getLocation('America/Chicago');
    final today = tz.TZDateTime.now(chicago);
    final todayDate = DateTime(today.year, today.month, today.day);
    final maxDate = todayDate.add(const Duration(days: 14));

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: todayDate,
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

  // ⭐ Go to today (Chicago timezone)
  void goToToday() {
    final chicago = tz.getLocation('America/Chicago');
    final today = tz.TZDateTime.now(chicago);
    final todayDate = DateTime(today.year, today.month, today.day);

    if (!selectedDate.isAtSameMomentAs(todayDate)) {
      selectedDate = todayDate;
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