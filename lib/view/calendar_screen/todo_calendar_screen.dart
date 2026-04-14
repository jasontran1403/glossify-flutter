import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/view/receptionist_screen/time_picker.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../api/api_service.dart';
import '../../utils/app_colors/app_colors.dart';
import '../../utils/constant/staff_slot.dart';
import '../bokking_screen/booking_schedule_screen.dart';
import '../bottombar_screen/bottomscreen_view_user.dart';

class TodoCalendarScreen extends StatefulWidget {
  final int staffId;
  final String staffName;
  final int storeId;
  final List<int> serviceIds;
  final List<String> serviceNames;
  final List<int> serviceTimes;

  const TodoCalendarScreen({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.storeId,
    required this.serviceIds,
    required this.serviceNames,
    required this.serviceTimes,
  });

  @override
  State<TodoCalendarScreen> createState() => _TodoCalendarScreenState();
}

class _TodoCalendarScreenState extends State<TodoCalendarScreen> {
  late DateTime selectedDate;
  final ScrollController _mainScrollController = ScrollController();
  final double _hourHeight = 120.0;
  bool isLoading = false;
  bool agreedMarketing = false;

  List<StaffSlot> slots = [];

  StaffSlot? selectedSlot;
  String? selectedSlotStartTime;

  final GlobalKey _gridContainerKey = GlobalKey();
  bool isCreatingBooking = false;
  final int _startHour = 8;
  final int _displayHours = 12;

  List<PhoneNumber> savedPhoneNumbers = [];
  PhoneNumber? primaryPhoneNumber;
  bool isExpanded = false;
  bool isLoadingPhones = false;

  String? errorMessage;
  Timer? countdownTimer;
  int remainingSeconds = 0;

  Timer? _currentTimeTimer;

  Map<DateTime, List<Task>> eventsByDate = {};
  Map<DateTime, List<DayOffSlot>> dayOffsByDate = {};

  int get totalDurationMinutes {
    return widget.serviceTimes.fold(0, (sum, time) => sum + time);
  }

  int get totalSlots {
    return (totalDurationMinutes / 15).ceil();
  }

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    selectedDate = getChicagoToday();

    fetchSchedule();
    fetchSavedPhoneNumbers();

    _currentTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
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
      final nowChicago = getChicagoNow();
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

      final currentTotalMinutes = now.hour * 60 + now.minute;
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
      return (null, null);
    }
  }

  Future<void> fetchSavedPhoneNumbers() async {
    setState(() => isLoadingPhones = true);
    try {
      final phones = await ApiService.getUserPhoneNumbers();
      setState(() {
        savedPhoneNumbers = phones;
        primaryPhoneNumber = phones.firstWhere(
              (phone) => phone.isPrimary,
          orElse: () => phones.first,
        );
      });
    } catch (e) {
      print('Error fetching phone numbers: $e');
    } finally {
      setState(() => isLoadingPhones = false);
    }
  }

  Future<void> savePhoneNumber(String phone) async {
    try {
      await ApiService.savePhoneNumber(phone);
      await fetchSavedPhoneNumbers();
    } catch (e) {
      print('Error saving phone number: $e');
    }
  }

  Future<void> setPrimaryPhoneNumber(int phoneId) async {
    try {
      await ApiService.setPrimaryPhoneNumber(phoneId);
      await fetchSavedPhoneNumbers();
    } catch (e) {
      print('Error setting primary phone: $e');
    }
  }

  Future<void> deletePhoneNumber(int phoneId) async {
    try {
      await ApiService.deletePhoneNumber(phoneId);
      await fetchSavedPhoneNumbers();
    } catch (e) {
      print('Error deleting phone number: $e');
    }
  }

  String _formatPhoneNumber(String digits) {
    if (digits.isEmpty) return '';
    if (digits.startsWith('1') && digits.length == 1) return '';
    if (digits.length > 1) digits = digits.substring(1);
    if (digits.length > 11) digits = digits.substring(0, 11);
    if (digits.length <= 3) return '+1 ($digits';
    if (digits.length <= 6) return '+1 (${digits.substring(0, 3)}) ${digits.substring(3)}';
    return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay _roundUpTo15Minutes(TimeOfDay time) {
    int minute = time.minute;
    int hour = time.hour;
    if (minute == 0 || minute == 15 || minute == 30 || minute == 45) return time;
    if (minute > 0 && minute < 15) return TimeOfDay(hour: hour, minute: 15);
    if (minute > 15 && minute < 30) return TimeOfDay(hour: hour, minute: 30);
    if (minute > 30 && minute < 45) return TimeOfDay(hour: hour, minute: 45);
    hour = (hour + 1) % 24;
    return TimeOfDay(hour: hour, minute: 0);
  }

  Future<void> fetchSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getStaffSchedule(
        staffId: widget.staffId,
        type: 0,
        date: selectedDate,
      );

      List<Task> bookedEvents = [];
      List<DayOffSlot> dayOffSlots = [];
      final List<Color> colors = [Colors.blue, Colors.purple, Colors.green, Colors.orange, Colors.red];

      for (var slot in data) {
        // Check if it's a day-off
        if (slot.bookingId == -1 || slot.status == 'DAY_OFF') {
          try {
            final startTime = _parseTime(slot.startTime);
            final endTime = _parseTime(slot.endTime);

            dayOffSlots.add(DayOffSlot(
              startTime: startTime,
              endTime: endTime,
              reason: slot.reason,
            ));
          } catch (e) {
            print('Error parsing day-off: $e');
          }
        }
        // Regular bookings
        else if (slot.status == 'BOOKED' || slot.status == 'PAST') {
          try {
            final startTime = _parseTime(slot.startTime);
            final endTimeRaw = _parseTime(slot.endTime);
            final actualDurationMinutes = (endTimeRaw.hour * 60 + endTimeRaw.minute) -
                (startTime.hour * 60 + startTime.minute);
            final endTime = _roundUpTo15Minutes(endTimeRaw);
            final color = colors[slot.services % colors.length];

            bookedEvents.add(Task(
              fullName: slot.fullName,
              color: color,
              startTime: startTime,
              endTime: endTime,
              taskCount: slot.services,
              actualDurationMinutes: actualDurationMinutes,
            ));
          } catch (e) {
            print('Error parsing booking: $e');
          }
        }
      }

      final dateKey = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      setState(() {
        slots = data;
        eventsByDate[dateKey] = bookedEvents;
        dayOffsByDate[dateKey] = dayOffSlots;
        errorMessage = null;
        selectedSlot = null;
        selectedSlotStartTime = null;
        remainingSeconds = 0;
        countdownTimer?.cancel();
      });
    } catch (e) {
      print('Error in fetchSchedule: $e');

      setState(() {
        slots = [];
        final dateKey = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        eventsByDate[dateKey] = [];
        dayOffsByDate[dateKey] = [];
        errorMessage = "Lỗi khi lấy lịch hẹn: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    countdownTimer?.cancel();
    _currentTimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildWeekHeader(),
          Expanded(child: _buildCalendarContent()),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    final nowChicago = getChicagoNow();
    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final dates = List.generate(7, (index) => nowChicago.add(Duration(days: index)));

    return Container(
      padding: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
      child: Row(
        children: [
          const SizedBox(width: 20),
          ...List.generate(7, (index) {
            final currentDate = dates[index];
            final isSelected = currentDate.day == selectedDate.day &&
                currentDate.month == selectedDate.month &&
                currentDate.year == selectedDate.year;
            final isToday = currentDate.day == nowChicago.day &&
                currentDate.month == nowChicago.month &&
                currentDate.year == nowChicago.year;

            final weekdayIndex = currentDate.weekday == 7 ? 0 : currentDate.weekday;

            return Expanded(
              child: GestureDetector(
                onTap: () async {
                  if (currentDate.day != selectedDate.day ||
                      currentDate.month != selectedDate.month ||
                      currentDate.year != selectedDate.year) {
                    setState(() {
                      selectedDate = currentDate;
                      isLoading = true;
                    });
                    await fetchSchedule();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weekDays[weekdayIndex],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue
                            : (isToday ? Colors.blue.withOpacity(0.1) : Colors.transparent),
                        shape: BoxShape.circle,
                        border: isToday && !isSelected ? Border.all(color: Colors.blue, width: 1) : null,
                      ),
                      child: Center(
                        child: Text(
                          '${currentDate.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : (isToday ? Colors.blue : Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCalendarContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Loading events...', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    final selectedDateKey = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dayEvents = eventsByDate[selectedDateKey] ?? [];
    final dayOffSlots = dayOffsByDate[selectedDateKey] ?? [];

    final sortedEvents = List<Task>.from(dayEvents)
      ..sort((a, b) => (a.startTime.hour * 60 + a.startTime.minute)
          .compareTo(b.startTime.hour * 60 + b.startTime.minute));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2.0),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.blue),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: showConfirmationDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Make Appointment'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const Divider(thickness: 2, color: Colors.grey, height: 10),
        Expanded(
          child: SingleChildScrollView(
            controller: _mainScrollController,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: _displayHours * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildEventsColumn(sortedEvents, dayOffSlots),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsColumn(List<Task> dayEvents, List<DayOffSlot> dayOffSlots) {
    return Container(
      key: _gridContainerKey,
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey[300]!, width: 1))),
      child: SizedBox(
        height: _displayHours * _hourHeight,
        child: Stack(
          children: [
            _buildGridBackground(),
            _buildCurrentTimeLine(),
            // Day-offs render FIRST (behind bookings)
            ...dayOffSlots.map((dayOff) => _buildDayOffCard(dayOff)).toList(),
            // Bookings render SECOND (on top of day-offs)
            ...dayEvents.map((task) => _buildEventCard(task)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOffCard(DayOffSlot dayOff) {
    final startMinutes = dayOff.startTime.hour * 60 + dayOff.startTime.minute;
    final endMinutes = dayOff.endTime.hour * 60 + dayOff.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    final top = ((startMinutes / 60.0) - _startHour) * _hourHeight;
    final height = (durationMinutes / 60.0) * _hourHeight;

    // Don't render if outside visible range
    if (top < 0 || top + height > _displayHours * _hourHeight) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: 60,
      right: 0,
      height: height.clamp(60.0, double.infinity),
      child: GestureDetector(
        onTap: () => _showDayOffInfo(dayOff),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // ✅ CHANGED: Bright orange background
            color: Colors.orange[300],
            borderRadius: BorderRadius.circular(6),
            // ✅ CHANGED: Orange border
            border: Border.all(color: Colors.orange[700]!, width: 2),
            // ✅ CHANGED: Orange glow shadow
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
              const SizedBox(height: 8),
              const Text(
                'Day Off',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatTime(dayOff.startTime)} - ${_formatTime(dayOff.endTime)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasDayOffConflict(DateTime date, TimeOfDay startTime, int durationMinutes) {
    final dayOffs = dayOffsByDate[date] ?? [];
    if (dayOffs.isEmpty) return false;

    final newStartMinutes = startTime.hour * 60 + startTime.minute;
    final newEndMinutes = newStartMinutes + durationMinutes;

    for (final dayOff in dayOffs) {
      final dayOffStart = dayOff.startTime.hour * 60 + dayOff.startTime.minute;
      final dayOffEnd = dayOff.endTime.hour * 60 + dayOff.endTime.minute;

      // Check overlap: booking overlaps with day-off
      if (newStartMinutes < dayOffEnd && newEndMinutes > dayOffStart) {
        return true;
      }
    }

    return false;
  }

  void _showDayOffInfo(DayOffSlot dayOff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_busy, color: Colors.grey),
            SizedBox(width: 8),
            Text('Staff Day Off'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Time', '${_formatTime(dayOff.startTime)} - ${_formatTime(dayOff.endTime)}'),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This stylist is off during this time. Please choose another time or date.',
                      style: TextStyle(fontSize: 13),
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeLine() {
    final (position, timeLabel) = _getCurrentTimeLinePosition();
    if (position == null || timeLabel == null) return const SizedBox.shrink();

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
            left: 16,
            top: -30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                timeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBackground() {
    return Stack(
      children: [
        Container(color: Colors.white),
        ...List.generate(_displayHours + 1, (index) {
          return Positioned(
            top: index * _hourHeight,
            left: 0,
            right: 0,
            child: Container(height: 1.5, color: Colors.grey[400]!),
          );
        }),
        ...List.generate(2 * _displayHours, (index) {
          if (index % 2 != 0) {
            return Positioned(
              top: (index * _hourHeight / 2),
              left: 0,
              right: 0,
              child: Container(height: 1.0, color: Colors.grey[300]!.withOpacity(0.7)),
            );
          }
          return const SizedBox.shrink();
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
        ...List.generate(_displayHours, (index) {
          final hour = _startHour + index;
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final period = hour < 12 ? 'AM' : 'PM';
          return Positioned(
            top: (index * _hourHeight) + 4,
            left: 8,
            child: Text('$displayHour $period',
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          );
        }),
      ],
    );
  }

  Widget _buildEventCard(Task task) {
    final startMinutes = task.startTime.hour * 60 + task.startTime.minute;
    final endMinutes = task.endTime.hour * 60 + task.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final displayDuration = task.actualDurationMinutes ?? durationMinutes;
    final top = ((startMinutes / 60.0) - _startHour) * _hourHeight;
    final height = (durationMinutes / 60.0) * _hourHeight;

    if (top < 0 || top + height > _displayHours * _hourHeight) return const SizedBox.shrink();

    return Positioned(
      top: top,
      left: 60,
      right: 0,
      height: height.clamp(24.0, double.infinity),
      child: GestureDetector(
        onTap: () => _showEventDetails(task),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(horizontal: height > 40 ? 12 : 8, vertical: height > 40 ? 8 : 4),
          decoration: BoxDecoration(
            color: task.color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3, offset: const Offset(0, 1))],
            border: Border.all(color: task.color.withOpacity(0.3), width: 0.5),
          ),
          child: _buildEventCardContent(task, displayDuration, height),
        ),
      ),
    );
  }

  Widget _buildEventCardContent(Task task, int durationMinutes, double cardHeight) {
    if (task.taskCount == 1) {
      return Row(
        children: [
          Expanded(
            child: Text(task.fullName,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('${durationMinutes}m',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.fullName,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (cardHeight > 60) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.access_time, color: Colors.white.withOpacity(0.9), size: 10),
              const SizedBox(width: 4),
              Text('${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 9, fontWeight: FontWeight.w500)),
            ]),
          ],
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${task.taskCount} ${task.taskCount > 1 ? 'services' : 'service'}',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 9, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('${durationMinutes}m',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'am' : 'pm';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  void _showEventDetails(Task task) {
    final actualDuration = task.actualDurationMinutes ??
        ((task.endTime.hour * 60 + task.endTime.minute) - (task.startTime.hour * 60 + task.startTime.minute));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(task.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}'),
            const SizedBox(height: 8),
            Text('Duration: $actualDuration minutes'),
            const SizedBox(height: 8),
            Text('Services: ${task.taskCount}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  bool _isTimeSlotAvailable(DateTime date, TimeOfDay startTime, int durationMinutes) {
    final dayEvents = eventsByDate[date] ?? [];
    final newStartMinutes = startTime.hour * 60 + startTime.minute;
    final newEndMinutes = newStartMinutes + durationMinutes;

    for (final event in dayEvents) {
      final existingStart = event.startTime.hour * 60 + event.startTime.minute;
      final existingEnd = event.endTime.hour * 60 + event.endTime.minute;
      if (newStartMinutes < existingEnd && newEndMinutes > existingStart) return false;
    }
    return true;
  }

  void showConfirmationDialog() {
    final durationMinutes = totalDurationMinutes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final phoneController = TextEditingController();
        final phoneFocusNode = FocusNode();
        String phoneError = '';
        bool isPhoneValid = false;
        bool localAgreedMarketing = agreedMarketing;
        bool showAllPhones = false;
        bool localMarkUnchange = false;

        TimeOfDay? selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
        TimeOfDay? calculatedEndTime;

        TimeOfDay calculateEndTime(TimeOfDay start, int totalMinutes) {
          final total = start.hour * 60 + start.minute + totalMinutes;
          return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
        }

        bool isTimeSlotAvailable(DateTime date, TimeOfDay startTime, int duration) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final events = eventsByDate[dateKey] ?? [];
          final startMins = startTime.hour * 60 + startTime.minute;
          final endMins = startMins + duration;
          for (final e in events) {
            final eStart = e.startTime.hour * 60 + e.startTime.minute;
            final eEnd = e.endTime.hour * 60 + e.endTime.minute;
            if (startMins < eEnd && endMins > eStart) return false;
          }
          return true;
        }

        void validatePhoneNumber(String phone) {
          final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
          if (cleaned.isEmpty) {
            phoneError = 'Phone number is required';
            isPhoneValid = false;
          } else if (cleaned.length != 11) {
            phoneError = 'Phone number must be 10 digits (not include +1)';
            isPhoneValid = false;
          } else {
            final areaCode = int.tryParse(cleaned.substring(1, 4)) ?? 0;
            if (areaCode < 200 || areaCode > 999) {
              phoneError = 'Invalid area code';
              isPhoneValid = false;
            } else {
              phoneError = '';
              isPhoneValid = true;
            }
          }
        }

        if (primaryPhoneNumber != null) {
          phoneController.text = primaryPhoneNumber!.formattedPhone;
          validatePhoneNumber(primaryPhoneNumber!.phoneNumber);
        }

        if (selectedStartTime != null) calculatedEndTime = calculateEndTime(selectedStartTime!, durationMinutes);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (selectedStartTime != null) calculatedEndTime = calculateEndTime(selectedStartTime!, durationMinutes);

            final dateKey = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
            final available = selectedStartTime != null && isTimeSlotAvailable(dateKey, selectedStartTime!, durationMinutes);
            final hasDayOffConflict = selectedStartTime != null && _hasDayOffConflict(dateKey, selectedStartTime!, durationMinutes);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.calendar_today, color: AppColors.primaryColor),
                  SizedBox(width: 8),
                  Text("Appointment confirm", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text("Beauty Specialist: ${widget.staffName}", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("Service names: ${widget.serviceNames.join(', ')}", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text("Time: "),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDialog<TimeOfDay>(
                                context: context,
                                builder: (_) => CustomTimePickerDialog(
                                  initialTime: selectedStartTime ?? const TimeOfDay(hour: 9, minute: 0),
                                  onTimeChanged: (time) => setDialogState(() => selectedStartTime = time),
                                ),
                              );
                              if (picked == null) return;

                              final totalMins = picked.hour * 60 + picked.minute;
                              if (totalMins < 9 * 60 || totalMins > 19 * 60) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Time must be between 9:00 AM and 7:00 PM.')),
                                );
                                return;
                              }

                              final nowChicago = getChicagoNow();
                              final isFuture = !(selectedDate.year == nowChicago.year &&
                                  selectedDate.month == nowChicago.month &&
                                  selectedDate.day == nowChicago.day &&
                                  totalMins <= nowChicago.hour * 60 + nowChicago.minute);

                              if (isFuture) {
                                setDialogState(() => selectedStartTime = picked);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a future time.')),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(selectedStartTime?.format(context) ?? 'Select time', style: const TextStyle(fontSize: 16)),
                                  const Icon(Icons.access_time),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (hasDayOffConflict) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_busy, color: Colors.red[700], size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Cannot book during staff day-off',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (selectedStartTime != null && calculatedEndTime != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (available && !hasDayOffConflict)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: (available && !hasDayOffConflict) ? Colors.green : Colors.red,
                              width: 1
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${selectedStartTime!.format(context)} - ${calculatedEndTime!.format(context)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text("Estimated: $durationMinutes mins", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text("Please select a start time.", style: TextStyle(color: Colors.orange, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: phoneController,
                            focusNode: phoneFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Phone Number *',
                              hintText: '+1 (XXX) XXX-XXXX',
                              errorText: phoneError.isNotEmpty ? phoneError : null,
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            onChanged: (value) {
                              final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                              if (digits.length > 11) {
                                final trimmedDigits = digits.substring(0, 11);
                                phoneController.text = _formatPhoneNumber(trimmedDigits);
                                phoneController.selection = TextSelection.collapsed(offset: phoneController.text.length);
                                validatePhoneNumber(trimmedDigits);
                                setDialogState(() {});
                                return;
                              }
                              final formatted = _formatPhoneNumber(digits);
                              if (formatted != phoneController.text) {
                                phoneController.text = formatted;
                                phoneController.selection = TextSelection.collapsed(offset: formatted.length);
                              }
                              validatePhoneNumber(digits);
                              setDialogState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final cleanedPhone = phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
                            if (cleanedPhone.length == 11) {
                              await savePhoneNumber(cleanedPhone);
                              setDialogState(() => showAllPhones = false);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: localMarkUnchange,
                            activeColor: Colors.orange,
                            onChanged: (value) => setDialogState(() => localMarkUnchange = value ?? false),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 18),
                                    const SizedBox(width: 4),
                                    const Text('Priority Booking',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Keep this staff assignment unchanged during updates',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: localAgreedMarketing,
                          activeColor: AppColors.primaryColor,
                          onChanged: (val) => setDialogState(() => localAgreedMarketing = val ?? false),
                        ),
                        const Expanded(
                          child: Text("I consent to receive marketing and notification SMS messages.", style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              actions: [
                TextButton(
                  onPressed: isCreatingBooking ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (localAgreedMarketing && isPhoneValid && !isCreatingBooking && selectedStartTime != null && available && !hasDayOffConflict)
                        ? AppColors.primaryColor
                        : AppColors.porcelainColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (localAgreedMarketing && isPhoneValid && !isCreatingBooking && selectedStartTime != null && available && !hasDayOffConflict)
                      ? () async {
                    setState(() => isCreatingBooking = true);
                    setDialogState(() {});

                    agreedMarketing = localAgreedMarketing;
                    final userId = await ApiService.getUserId();
                    final customerPhone = phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
                    final bookingDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedStartTime!.hour,
                      selectedStartTime!.minute,
                    );
                    final startTimeStr = DateFormat('yyyy-MM-dd HH:mm').format(bookingDateTime);

                    final res = await ApiService.createBooking(
                      staffId: widget.staffId,
                      customerId: userId!,
                      customerPhone: customerPhone,
                      startTime: startTimeStr,
                      storeId: widget.storeId,
                      markUnchange: localMarkUnchange,
                      serviceIds: widget.serviceIds,
                    );

                    if (!mounted) return;

                    if (res['success'] == true) {
                      await fetchSchedule();
                      setState(() => isCreatingBooking = false);
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? "Booking successful"), backgroundColor: Colors.green),
                      );
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const BottomNavBarView(initialTabIndex: 2)),
                            (route) => false,
                      );
                    } else {
                      setState(() => isCreatingBooking = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? "Booking failed"), backgroundColor: Colors.red),
                      );
                    }
                  }
                      : null,
                  child: isCreatingBooking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text("Confirm", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => setState(() => isCreatingBooking = false));
  }
}

class Task {
  final String fullName;
  final Color color;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int taskCount;
  final int? actualDurationMinutes;

  Task({
    required this.fullName,
    required this.color,
    required this.startTime,
    required this.endTime,
    this.taskCount = 2,
    this.actualDurationMinutes,
  });
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