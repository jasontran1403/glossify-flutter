import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/view/receptionist_screen/task_model.dart';
import 'package:intl/intl.dart';

import '../../api/api_service.dart';
import '../../api/staff_schedule_model.dart';
import '../../utils/app_colors/app_colors.dart';
import '../home_screen/detail_stylist.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class ScheduleCalendarScreen extends StatefulWidget {
  final int storeId;
  final List<int> serviceIds;
  final List<String> serviceNames;
  final int? userId;

  const ScheduleCalendarScreen({
    super.key,
    required this.storeId,
    this.serviceIds = const [],
    this.serviceNames = const [],
    this.userId,
  });

  @override
  State<ScheduleCalendarScreen> createState() => _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState extends State<ScheduleCalendarScreen> {
  late DateTime selectedDate;
  Timer? _currentTimeTimer;

  List<ServiceModel> selectedServices = [];
  int? selectedStaffIdForBooking;
  DateTime? selectedTimeForBooking;

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final double _hourHeight = 120.0;
  final double _timeColumnWidth = 90.0;
  bool isLoading = false;
  bool agreedMarketing = false;

  bool _isSyncing = false;

  List<StaffSchedule> staffSchedules = [];
  Map<int, List<Task>> eventsByStaffId = {};
  Map<int, List<DayOffSlot>> dayOffsByStaffId = {};

  Task? selectedSlot;
  String? selectedSlotStartTime;

  bool isCreatingBooking = false;
  final int _startHour = 7;
  final int _displayHours = 12;

  String? errorMessage;
  Timer? countdownTimer;
  int remainingSeconds = 0;

  Map<DateTime, List<Task>> eventsByDate = {};

  final DateFormat _dateFormat = DateFormat('MMMM EEE dd, yyyy');

  final ScrollController _staffHeaderScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    tz.initializeTimeZones();

    selectedDate = getChicagoToday();

    _mainScrollController.addListener(_onMainScroll);

    _horizontalScrollController.addListener(() {
      if (_horizontalScrollController.hasClients &&
          _staffHeaderScrollController.hasClients) {
        if (!_isSyncing) {
          _isSyncing = true;
          _staffHeaderScrollController.jumpTo(
            _horizontalScrollController.offset,
          );
          _isSyncing = false;
        }
      }
    });

    _staffHeaderScrollController.addListener(() {
      if (_horizontalScrollController.hasClients &&
          _staffHeaderScrollController.hasClients) {
        if (!_isSyncing) {
          _isSyncing = true;
          _horizontalScrollController.jumpTo(
            _staffHeaderScrollController.offset,
          );
          _isSyncing = false;
        }
      }
    });

    _currentTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    fetchSchedule();
  }

  tz.TZDateTime getChicagoNow() {
    final chicago = tz.getLocation('America/Chicago');
    return tz.TZDateTime.now(chicago);
  }

  DateTime getChicagoToday() {
    final chicagoNow = getChicagoNow();
    return DateTime(chicagoNow.year, chicagoNow.month, chicagoNow.day);
  }

  (double? position, String? timeLabel) _getCurrentTimeLinePosition() {
    try {
      final chicago = tz.getLocation('America/Chicago');
      final nowChicago = tz.TZDateTime.now(chicago);

      final now = DateTime(
        nowChicago.year,
        nowChicago.month,
        nowChicago.day,
        nowChicago.hour,
        nowChicago.minute,
        nowChicago.second,
      );

      if (selectedDate.year != now.year ||
          selectedDate.month != now.month ||
          selectedDate.day != now.day) {
        return (null, null);
      }

      final currentTime = TimeOfDay.fromDateTime(now);
      final currentTotalMinutes = currentTime.hour * 60 + currentTime.minute;
      final startTotalMinutes = _startHour * 60;

      if (currentTotalMinutes >= startTotalMinutes &&
          currentTotalMinutes <= (_startHour + _displayHours) * 60) {
        final minutesFromStart = currentTotalMinutes - startTotalMinutes;
        final position = (minutesFromStart / 60.0) * _hourHeight;
        final timeLabel = DateFormat('HH:mm:ss').format(now);
        return (position, timeLabel);
      }

      return (null, null);
    } catch (e) {
      final now = DateTime.now();

      if (selectedDate.year != now.year ||
          selectedDate.month != now.month ||
          selectedDate.day != now.day) {
        return (null, null);
      }

      final currentTime = TimeOfDay.fromDateTime(now);
      final currentTotalMinutes = currentTime.hour * 60 + currentTime.minute;
      final startTotalMinutes = _startHour * 60;

      if (currentTotalMinutes >= startTotalMinutes &&
          currentTotalMinutes <= (_startHour + _displayHours) * 60) {
        final minutesFromStart = currentTotalMinutes - startTotalMinutes;
        final position = (minutesFromStart / 60.0) * _hourHeight;
        final timeLabel = DateFormat('HH:mm:ss').format(now);
        return (position, timeLabel);
      }

      return (null, null);
    }
  }

  bool _isTimeSlotAvailableForBooking(DateTime dateTime) {
    final chicago = tz.getLocation('America/Chicago');
    final nowChicago = tz.TZDateTime.now(chicago);

    final now = DateTime(
      nowChicago.year,
      nowChicago.month,
      nowChicago.day,
      nowChicago.hour,
      nowChicago.minute,
    );

    if (dateTime.year != now.year ||
        dateTime.month != now.month ||
        dateTime.day != now.day) {
      return true;
    }

    return dateTime.isAfter(now);
  }

  // ✅ NEW: Check if booking conflicts with staff day-off
  bool _checkDayOffConflict(int staffId, TimeOfDay startTime, int durationMinutes) {
    final dayOffs = dayOffsByStaffId[staffId] ?? [];
    if (dayOffs.isEmpty) return false;

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = startMinutes + durationMinutes;

    for (final dayOff in dayOffs) {
      final dayOffStart = dayOff.startTime.hour * 60 + dayOff.startTime.minute;
      final dayOffEnd = dayOff.endTime.hour * 60 + dayOff.endTime.minute;

      // Check if booking overlaps with day-off
      if (startMinutes < dayOffEnd && endMinutes > dayOffStart) {
        return true;
      }
    }

    return false;
  }

  void _onStaffColumnTap(StaffSchedule schedule, Offset localPosition) {
    final double clickedY = localPosition.dy;
    final double hourOffset = clickedY / _hourHeight;
    final int totalMinutes = (_startHour * 60) + (hourOffset * 60).floor();
    final int clickedHour = totalMinutes ~/ 60;
    final int clickedMinute = totalMinutes % 60;

    final int roundedMinute = (clickedMinute ~/ 15) * 15;
    final int finalHour = clickedHour;
    final int finalMinute = roundedMinute;

    final clickedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      finalHour,
      finalMinute,
    );

    selectedStaffIdForBooking = schedule.staffId;
    selectedTimeForBooking = clickedDateTime;

    _showServiceSelectionSheet(schedule);
  }

  Future<void> _showServiceSelectionSheet(StaffSchedule schedule) async {
    selectedServices.clear();

    List<ServiceModel> staffServices = [];
    bool isLoading = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (isLoading) {
              ApiService.getStaffDetailForReceptionist(schedule.staffId)
                  .then((staffDetail) {
                setSheetState(() {
                  staffServices = staffDetail.services;
                  isLoading = false;
                });
              }).catchError((e) {
                setSheetState(() {
                  isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to load services: $e')),
                );
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 80,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Services for ${schedule.fullName}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select up to 6 services (${selectedServices.length}/6)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: staffServices.length,
                      itemBuilder: (context, index) {
                        final service = staffServices[index];
                        final isSelected = selectedServices.any(
                              (s) => s.id == service.id,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundImage: _isValidUrl(service.avatar)
                                  ? NetworkImage(service.avatar)
                                  : null,
                              child: !_isValidUrl(service.avatar)
                                  ? const Icon(
                                Icons.content_cut,
                                size: 20,
                              )
                                  : null,
                            ),
                            title: Text(
                              service.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '\$${service.price.toStringAsFixed(2)} • ${service.time} mins',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: selectedServices.length >= 6 &&
                                  !isSelected
                                  ? null
                                  : (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selectedServices.add(
                                      service,
                                    );
                                  } else {
                                    selectedServices.removeWhere(
                                          (s) => s.id == service.id,
                                    );
                                  }
                                });
                              },
                              activeColor: AppColors.primaryColor,
                            ),
                            onTap: () {
                              if (selectedServices.length < 6 ||
                                  isSelected) {
                                setSheetState(() {
                                  if (isSelected) {
                                    selectedServices.removeWhere(
                                          (s) => s.id == service.id,
                                    );
                                  } else {
                                    selectedServices.add(service);
                                  }
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: selectedServices.isEmpty
                          ? null
                          : () {
                        Navigator.pop(context);
                        _showBookingConfirmation(schedule);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedServices.isEmpty
                            ? Colors.grey
                            : AppColors.primaryColor,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Next (${selectedServices.length} service${selectedServices.length > 1 ? 's' : ''})',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onMainScroll() {
    if (_isSyncing) return;
  }

  void _onHorizontalScroll() {
    if (_isSyncing) return;
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatPhoneNumber(String digits) {
    if (digits.isEmpty) return '';

    if (digits.startsWith('1') && digits.length == 1) {
      return '';
    }

    if (digits.length > 1) {
      digits = digits.substring(1);
    }

    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    if (digits.length <= 3) {
      return '+1 ($digits';
    } else if (digits.length <= 6) {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getAllStaffSchedule(
        storeId: widget.storeId,
        type: 0,
        date: selectedDate,
      );

      if (data.isEmpty) {
        setState(() {
          staffSchedules = [];
          eventsByStaffId.clear();
          dayOffsByStaffId.clear();
          errorMessage = "Không có nhân viên nào trong ngày này.";
          final dateKey = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
          );
          eventsByDate[dateKey] = [];
        });
      } else {
        Map<int, List<Task>> tempEventsByStaff = {};
        Map<int, List<DayOffSlot>> tempDayOffsByStaff = {};
        final List<Color> colors = [
          Colors.blue,
          Colors.purple,
          Colors.green,
          Colors.orange,
          Colors.red,
        ];

        for (var schedule in data) {
          List<Task> staffEvents = [];
          List<DayOffSlot> staffDayOffs = [];

          if (schedule.fullName == "Anyone") continue;

          for (var slot in schedule.slots) {
            // Check if day-off
            if (slot.bookingId == -1 || slot.status == 'DAY_OFF') {
              final startTime = _parseTime(slot.startTime);
              final endTime = _parseTime(slot.endTime);

              staffDayOffs.add(DayOffSlot(
                startTime: startTime,
                endTime: endTime,
                reason: slot.reason,
              ));
              continue;
            }

            // Regular bookings
            final startTime = _parseTime(slot.startTime);
            final endTimeRaw = _parseTime(slot.endTime);

            final actualStartMinutes = startTime.hour * 60 + startTime.minute;
            final actualEndMinutes = endTimeRaw.hour * 60 + endTimeRaw.minute;
            final actualDurationMinutes = actualEndMinutes - actualStartMinutes;

            final endTime = _roundUpTo15Minutes(endTimeRaw);

            final color = colors[slot.services % colors.length];
            final task = Task(
              bookingId: slot.bookingId,
              markUnchange: slot.markUnchange,
              fullName: slot.fullName,
              customerAvt: slot.customerAvt,
              staffName: slot.fullName,
              startTime: startTime,
              endTime: endTime,
              status: slot.status,
              taskCount: slot.services,
              actualDurationMinutes: actualDurationMinutes,
            );
            staffEvents.add(task);
          }

          tempEventsByStaff[schedule.staffId] = staffEvents;
          tempDayOffsByStaff[schedule.staffId] = staffDayOffs;
        }

        final dateKey = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        setState(() {
          staffSchedules = data;
          eventsByStaffId = tempEventsByStaff;
          dayOffsByStaffId = tempDayOffsByStaff;
          eventsByDate[dateKey] = [];
          errorMessage = null;
          selectedSlot = null;
          selectedSlotStartTime = null;
          remainingSeconds = 0;
          countdownTimer?.cancel();
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        staffSchedules = [];
        eventsByStaffId.clear();
        dayOffsByStaffId.clear();
        final dateKey = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        eventsByDate[dateKey] = [];
        errorMessage = "Lỗi khi lấy lịch hẹn: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _goToPreviousDay() {
    final today = getChicagoToday();
    if (selectedDate.isAfter(today)) {
      setState(() {
        selectedDate = selectedDate.subtract(const Duration(days: 1));
      });
      fetchSchedule();
    }
  }

  void _goToNextDay() {
    final today = getChicagoToday();
    final maxDate = today.add(const Duration(days: 14));
    if (selectedDate.isBefore(maxDate)) {
      setState(() {
        selectedDate = selectedDate.add(const Duration(days: 1));
      });
      fetchSchedule();
    }
  }

  void _goToToday() {
    final chicago = tz.getLocation('America/Chicago');
    final nowChicago = tz.TZDateTime.now(chicago);

    final today = DateTime(nowChicago.year, nowChicago.month, nowChicago.day);

    if (!selectedDate.isAtSameMomentAs(today)) {
      setState(() {
        selectedDate = today;
      });
      fetchSchedule();
    }
  }

  Future<void> _showDatePicker() async {
    final todayChicago = getChicagoToday();
    final maxDate = todayChicago.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: todayChicago,
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
      setState(() {
        selectedDate = picked;
      });
      fetchSchedule();
    }
  }

  void startCountdown() {
    countdownTimer?.cancel();
    remainingSeconds = 180;
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        remainingSeconds--;
        if (remainingSeconds <= 0) {
          selectedSlot = null;
          selectedSlotStartTime = null;
          timer.cancel();
        }
      });
    });
  }

  String countdownText() {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onMainScroll);
    _horizontalScrollController.removeListener(_onHorizontalScroll);
    _mainScrollController.dispose();
    _horizontalScrollController.dispose();
    _staffHeaderScrollController.dispose();
    countdownTimer?.cancel();
    _currentTimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - _timeColumnWidth - 32;
    final int maxVisibleStaff = 4;
    final double staffColumnWidth = staffSchedules.isEmpty
        ? 180.0
        : availableWidth /
        (staffSchedules.length > maxVisibleStaff
            ? maxVisibleStaff
            : staffSchedules.length);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildDateHeader(),
          const Divider(thickness: 2, color: Colors.grey, height: 0),
          Expanded(child: _buildCalendarContent(staffColumnWidth)),
        ],
      ),
    );
  }

  Widget _buildCalendarContent(double staffColumnWidth) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Loading events...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: _timeColumnWidth),
            Expanded(
              child: SingleChildScrollView(
                controller: _staffHeaderScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: staffSchedules
                      .map(
                        (schedule) => Container(
                      width: staffColumnWidth,
                      height: 100,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!),
                          bottom: BorderSide(
                            color: Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: _isValidUrl(schedule.avatar)
                                ? NetworkImage(schedule.avatar)
                                : null,
                            backgroundColor: Colors.grey.shade200,
                            child: !_isValidUrl(schedule.avatar)
                                ? const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.grey,
                            )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            schedule.fullName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _mainScrollController,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: _displayHours * _hourHeight + 20,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _timeColumnWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          child: _buildTimeLabels(),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 10),
                            child: SizedBox(
                              height: _displayHours * _hourHeight,
                              child: Stack(
                                children: [
                                  _buildHorizontalGridLines(),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: staffSchedules.map((schedule) {
                                      return _buildStaffColumn(
                                        schedule,
                                        staffColumnWidth,
                                      );
                                    }).toList(),
                                  ),
                                  _buildCurrentTimeLine(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTimeLine() {
    final (position, timeLabel) = _getCurrentTimeLinePosition();

    if (position == null) return const SizedBox.shrink();

    return Positioned(
      top: position,
      left: 0,
      right: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: Colors.red,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Positioned(
            left: 4,
            top: -3,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: _timeColumnWidth,
            top: 14,
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  timeLabel ?? '--:--:--',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final isTodaySelected = selectedDate.isAtSameMomentAs(getChicagoToday());
    final dateLabel = _dateFormat.format(selectedDate);

    final chicagoTime = getChicagoNow();
    final isDST = chicagoTime.timeZoneOffset.inHours == -5;
    final tzAbbr = isDST ? 'CDT' : 'CST';
    final timeLabel =
        '${chicagoTime.hour.toString().padLeft(2, '0')}:${chicagoTime.minute.toString().padLeft(2, '0')}:${chicagoTime.second.toString().padLeft(2, '0')} $tzAbbr';

    return Container(
      padding: const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            color: Colors.blue,
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : _goToToday,
            child: Opacity(
              opacity: isLoading ? 0.5 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isTodaySelected
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isTodaySelected
                      ? Border.all(color: Colors.blue, width: 1)
                      : null,
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isTodaySelected ? Colors.blue : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : fetchSchedule,
            icon: Icon(
              Icons.refresh,
              color: isLoading ? Colors.grey : Colors.blue,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : _goToPreviousDay,
            icon: Icon(
              Icons.chevron_left,
              color: isLoading ? Colors.grey : Colors.blue,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isLoading ? null : _showDatePicker,
              child: Opacity(
                opacity: isLoading ? 0.5 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeLabel,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: isLoading ? null : _goToNextDay,
            icon: Icon(
              Icons.chevron_right,
              color: isLoading ? Colors.grey : Colors.blue,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalGridLines() {
    return Positioned.fill(
      child: Stack(
        children: [
          ...List.generate(_displayHours + 1, (index) {
            return Positioned(
              top: index * _hourHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 2.0,
                color: Colors.grey[500]!,
              ),
            );
          }),
          ...List.generate(_displayHours, (index) {
            return Positioned(
              top: (index * _hourHeight) + (_hourHeight / 2),
              left: 0,
              right: 0,
              child: Container(
                height: 1.5,
                color: Colors.grey[400]!,
              ),
            );
          }),
          ...List.generate(4 * _displayHours, (index) {
            if (index % 4 != 0 && index % 2 != 0) {
              return Positioned(
                top: (index * _hourHeight / 4),
                left: 0,
                right: 0,
                child: Container(height: 0.5, color: Colors.grey[200]!),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildTimeLabels() {
    return Stack(
      children: [
        ...List.generate(_displayHours, (index) {
          final hour = _startHour + index;
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final period = hour < 12 ? 'AM' : 'PM';

          return Positioned(
            top: (index * _hourHeight) - 8,
            left: 8,
            child: Text(
              '$displayHour:00 $period',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
        ...List.generate(_displayHours, (index) {
          final hour = _startHour + index;
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final period = hour < 12 ? 'AM' : 'PM';

          return Positioned(
            top: (index * _hourHeight + _hourHeight / 2) - 6,
            left: 8,
            child: Text(
              '$displayHour:30 $period',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black,
                fontWeight: FontWeight.w300,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStaffColumn(StaffSchedule schedule, double staffColumnWidth) {
    final events = eventsByStaffId[schedule.staffId] ?? [];
    final dayOffs = dayOffsByStaffId[schedule.staffId] ?? [];

    final sortedEvents = List<Task>.from(events)
      ..sort(
            (a, b) => (a.startTime.hour * 60 + a.startTime.minute).compareTo(
          b.startTime.hour * 60 + b.startTime.minute,
        ),
      );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) {
        _onStaffColumnTap(schedule, details.localPosition);
      },
      child: Container(
        width: staffColumnWidth,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Day-offs FIRST (behind bookings)
            ...dayOffs.map((dayOff) => _buildDayOffCard(dayOff, schedule)).toList(),
            // Bookings SECOND (on top)
            ...sortedEvents
                .map((task) => _buildEventCard(task, schedule.fullName))
                .toList(),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Day-off card now handles long-press properly
  Widget _buildDayOffCard(DayOffSlot dayOff, StaffSchedule schedule) {
    final startMinutes = dayOff.startTime.hour * 60 + dayOff.startTime.minute;
    final endMinutes = dayOff.endTime.hour * 60 + dayOff.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    final top = ((startMinutes / 60.0) - _startHour) * _hourHeight;
    final height = (durationMinutes / 60.0) * _hourHeight;

    if (top < 0 || top + height > _displayHours * _hourHeight) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height.clamp(60.0, double.infinity),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // ✅ Tap → Show day-off info
          onTap: () {
            _showDayOffInfo(dayOff);
          },
          // ✅ Long press → Show warning that stylist is not available
          onLongPress: () {
            _showCannotBookDuringDayOff(schedule, dayOff);
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[300],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange[700]!, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy, color: Colors.white, size: 28),
                const SizedBox(height: 6),
                const Text(
                  'DAY OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTime(dayOff.startTime)} - ${_formatTime(dayOff.endTime)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Tap for details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Show warning when trying to book during day-off
  void _showCannotBookDuringDayOff(StaffSchedule schedule, DayOffSlot dayOff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                color: Colors.red[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cannot Book',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.red[700],
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${schedule.fullName} is Off',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This stylist is off from ${_formatTime(dayOff.startTime)} to ${_formatTime(dayOff.endTime)}.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.red[900],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You cannot create bookings during their day off period.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.red[900],
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Try booking with another stylist or choose a different time.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDayOffInfo(DayOffSlot dayOff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy,
                color: Colors.orange[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Stylist Day Off',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_formatTime(dayOff.startTime)} - ${_formatTime(dayOff.endTime)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.red[700],
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Stylist Not Available',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This stylist is off during this time. Please choose another day or another stylist.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[900],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Got it',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Task task, String staffName) {
    final startMinutes = task.startTime.hour * 60 + task.startTime.minute;
    final endMinutes = task.endTime.hour * 60 + task.endTime.minute;

    final durationMinutes = endMinutes - startMinutes;

    final displayDuration = task.actualDurationMinutes ?? durationMinutes;

    final top = ((startMinutes / 60.0) - _startHour) * _hourHeight;
    final height = (durationMinutes / 60.0) * _hourHeight;

    if (top < 0 || top + height > _displayHours * _hourHeight) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height.clamp(12.0, double.infinity),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _showEventDetails(task, staffName);
        },
        onLongPress: () {
          _showEventDetails(task, staffName);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(
            horizontal: height > 40 ? 12 : 8,
            vertical: height > 40 ? 8 : 4,
          ),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 0.5),
          ),
          child: _buildEventCardContent(task, displayDuration, height),
        ),
      ),
    );
  }

  Widget _buildEventCardContent(
      Task task,
      int durationMinutes,
      double cardHeight,
      ) {
    if (task.taskCount == 1) {
      return Row(
        children: [
          Expanded(
            child: Text(
              task.fullName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${durationMinutes}m',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (cardHeight > 60) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.white.withOpacity(0.9),
                  size: 10,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${task.taskCount} ${task.taskCount > 1 ? 'services' : 'service'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${durationMinutes}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour =
    time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'am' : 'pm';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  void _showEventDetails(Task task, String staffName) {
    final actualDuration = task.actualDurationMinutes ??
        ((task.endTime.hour * 60 + task.endTime.minute) -
            (task.startTime.hour * 60 + task.startTime.minute));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time: ${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Duration: ${actualDuration} minutes',
            ),
            const SizedBox(height: 8),
            Text('Services: ${task.taskCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBookingConfirmation(StaffSchedule schedule) {
    if (selectedServices.isEmpty || selectedTimeForBooking == null) return;
    bool markUnchange = false;

    final int durationMinutes = selectedServices
        .map((service) => service.time)
        .fold(0, (sum, time) => sum + time);

    final TimeOfDay startTime = TimeOfDay(
      hour: selectedTimeForBooking!.hour,
      minute: selectedTimeForBooking!.minute,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        TimeOfDay? calculatedEndTime;

        TimeOfDay calculateEndTime(TimeOfDay start, int duration) {
          int totalMinutes = start.hour * 60 + start.minute + duration;
          int endHour = (totalMinutes ~/ 60) % 24;
          int endMinute = totalMinutes % 60;
          return TimeOfDay(hour: endHour, minute: endMinute);
        }

        bool _isTimeSlotAvailable(
            int staffId,
            DateTime date,
            TimeOfDay startTime,
            int duration,
            ) {
          final events = eventsByStaffId[staffId] ?? [];
          final startTotalMinutes = startTime.hour * 60 + startTime.minute;
          final endTotalMinutes = startTotalMinutes + duration;

          for (final event in events) {
            final eventStart =
                event.startTime.hour * 60 + event.startTime.minute;
            final eventEnd = event.endTime.hour * 60 + event.endTime.minute;

            if (startTotalMinutes < eventEnd && endTotalMinutes > eventStart) {
              return false;
            }
          }
          return true;
        }

        calculatedEndTime = calculateEndTime(startTime, durationMinutes);

        // Check booking conflicts
        final isAvailable = _isTimeSlotAvailable(
          schedule.staffId,
          selectedDate,
          startTime,
          durationMinutes,
        );

        // ✅ NEW: Check day-off conflicts
        final hasDayOffConflict = _checkDayOffConflict(
          schedule.staffId,
          startTime,
          durationMinutes,
        );

        final canBook = isAvailable && !hasDayOffConflict;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.calendar_today, color: AppColors.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    "Confirm Appointment",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildInfoRow('Staff', schedule.fullName),
                      const SizedBox(height: 12),
                      const Text(
                        'Services:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...selectedServices.map(
                            (service) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  service.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                '${service.time}m',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '\$${service.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: canBook
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: canBook ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${startTime.format(context)} - ${calculatedEndTime!.format(context)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '${DateFormat('dd MMM yyyy').format(selectedDate)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Total: $durationMinutes mins",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              // ✅ Show day-off conflict message
                              if (hasDayOffConflict) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orange[300]!, width: 2),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.event_busy, color: Colors.orange[700], size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'This time conflicts with ${schedule.fullName}\'s day off. Please choose a different time.',
                                          style: TextStyle(
                                            color: Colors.orange[900],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // ✅ Show booking conflict message
                              if (!isAvailable && !hasDayOffConflict) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'This time slot conflicts with existing appointments. Please choose a different time.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (!canBook) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  hasDayOffConflict
                                      ? 'Tip: Try booking before or after the day-off period, or choose another stylist.'
                                      : 'Tip: Choose a time before or after the existing appointments.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: markUnchange,
                              activeColor: Colors.orange,
                              onChanged: (value) {
                                setDialogState(() {
                                  markUnchange = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Priority Booking',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Keep this staff assignment unchanged during updates',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isCreatingBooking
                      ? null
                      : () {
                    Navigator.pop(dialogContext);
                    _showServiceSelectionSheet(schedule);
                  },
                  child: const Text(
                    "Back",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    backgroundColor: (!isCreatingBooking && canBook)
                        ? AppColors.primaryColor
                        : AppColors.porcelainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (!isCreatingBooking && canBook)
                      ? () async {
                    setState(() {
                      isCreatingBooking = true;
                    });

                    setDialogState(() {});

                    String startTimeStr = DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(selectedTimeForBooking!);

                    final res =
                    await ApiService.receptionistCreateBooking(
                      staffId: schedule.staffId,
                      customerId: widget.userId!,
                      customerPhone: '10000000000',
                      startTime: startTimeStr,
                      storeId: widget.storeId,
                      markUnchange: markUnchange,
                      serviceIds:
                      selectedServices.map((s) => s.id).toList(),
                    );

                    if (!mounted) return;

                    if (res['success'] == true) {
                      await fetchSchedule();

                      setState(() {
                        isCreatingBooking = false;
                        selectedServices.clear();
                        selectedStaffIdForBooking = null;
                        selectedTimeForBooking = null;
                      });

                      Navigator.of(dialogContext).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  res['message'] ?? "Booking successful",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      Navigator.of(context).pop();
                    } else {
                      setState(() {
                        isCreatingBooking = false;
                      });
                      setDialogState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            res['message'] ?? "Booking failed",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                      : null,
                  child: isCreatingBooking
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Text(
                    "Confirm",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  TimeOfDay _roundUpTo15Minutes(TimeOfDay time) {
    int minute = time.minute;
    int hour = time.hour;

    if (minute == 0 || minute == 15 || minute == 30 || minute == 45) {
      return time;
    }

    if (minute > 0 && minute < 15) {
      return TimeOfDay(hour: hour, minute: 15);
    } else if (minute > 15 && minute < 30) {
      return TimeOfDay(hour: hour, minute: 30);
    } else if (minute > 30 && minute < 45) {
      return TimeOfDay(hour: hour, minute: 45);
    } else {
      hour = (hour + 1) % 24;
      return TimeOfDay(hour: hour, minute: 0);
    }
  }
}

class DayOffSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? reason;

  DayOffSlot({
    required this.startTime,
    required this.endTime,
    this.reason,
  });
}