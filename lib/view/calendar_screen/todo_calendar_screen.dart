import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/view/receptionist_screen/time_picker.dart';
import 'package:intl/intl.dart';

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

  const TodoCalendarScreen({
    Key? key,
    required this.staffId,
    required this.staffName,
    required this.storeId,
    required this.serviceIds,
    required this.serviceNames,
  }) : super(key: key);

  @override
  State<TodoCalendarScreen> createState() => _TodoCalendarScreenState();
}

class _TodoCalendarScreenState extends State<TodoCalendarScreen> {
  DateTime selectedDate = DateTime.now();
  final ScrollController _mainScrollController = ScrollController();
  final double _hourHeight = 120.0;
  bool isLoading = false;
  bool agreedMarketing = false;

  List<StaffSlot> slots = [];

  StaffSlot? selectedSlot;
  String? selectedSlotStartTime;

  // Thêm GlobalKey cho grid container
  final GlobalKey _gridContainerKey = GlobalKey();
  bool isCreatingBooking = false; // NEW: Track booking creation state
  final int _startHour = 8;
  final int _displayHours = 12;

  List<PhoneNumber> savedPhoneNumbers = [];
  PhoneNumber? primaryPhoneNumber;
  bool isExpanded = false;
  bool isLoadingPhones = false;

  String? errorMessage;
  Timer? countdownTimer;
  int remainingSeconds = 0;

  Map<DateTime, List<Task>> eventsByDate = {};

  @override
  void initState() {
    super.initState();
    fetchSchedule();
    fetchSavedPhoneNumbers(); // Load saved phone numbers
  }

  Future<void> fetchSavedPhoneNumbers() async {
    setState(() {
      isLoadingPhones = true;
    });
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
      setState(() {
        isLoadingPhones = false;
      });
    }
  }

  Future<void> savePhoneNumber(String phone) async {
    try {
      await ApiService.savePhoneNumber(phone);
      await fetchSavedPhoneNumbers(); // Refresh the list
    } catch (e) {
      print('Error saving phone number: $e');
    }
  }

  Future<void> setPrimaryPhoneNumber(int phoneId) async {
    try {
      await ApiService.setPrimaryPhoneNumber(phoneId);
      await fetchSavedPhoneNumbers(); // Refresh the list
    } catch (e) {
      print('Error setting primary phone: $e');
    }
  }

  Future<void> deletePhoneNumber(int phoneId) async {
    try {
      await ApiService.deletePhoneNumber(phoneId);
      await fetchSavedPhoneNumbers(); // Refresh the list
    } catch (e) {
      print('Error deleting phone number: $e');
    }
  }

  // Hàm định dạng số điện thoại mới
  String _formatPhoneNumber(String digits) {
    if (digits.isEmpty) return '';

    // Nếu số điện thoại bắt đầu bằng 1, loại bỏ nó vì đã có mã quốc gia +1
    if (digits.startsWith('1') && digits.length == 1) {
      return '';
    }

    if (digits.length > 1) {
      digits = digits.substring(1);
    }

    // Giới hạn tối đa 10 chữ số
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    // Định dạng số điện thoại
    if (digits.length <= 3) {
      return '+1 ($digits';
    } else if (digits.length <= 6) {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
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

      if (data.isEmpty) {
        setState(() {
          slots = [];
          errorMessage = "Không có slot nào trong ngày này.";
          final dateKey = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
          );
          eventsByDate[dateKey] = [];
        });
      } else {
        // Lọc các slot BOOKED hoặc PAST để tạo events
        List<Task> bookedEvents = [];

        final List<Color> colors = [
          Colors.blue,
          Colors.purple,
          Colors.green,
          Colors.orange,
          Colors.red,
        ];
        for (var slot in data) {
          if (slot.status == 'BOOKED' || slot.status == 'PAST') {
            final startTime = _parseTime(slot.startTime);
            final endTime = _parseTime(slot.endTime);
            final color = colors[slot.services % colors.length];
            final task = Task(
              fullName: slot.fullName,
              color: color,
              startTime: startTime,
              endTime: endTime,
              taskCount: slot.services,
            );
            bookedEvents.add(task);
          }
        }

        final dateKey = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        setState(() {
          slots = data;
          eventsByDate[dateKey] = bookedEvents;
          errorMessage = null;
          selectedSlot = null;
          selectedSlotStartTime = null;
          remainingSeconds = 0;
          countdownTimer?.cancel();
        });
      }
    } catch (e) {
      print('Error in fetchSchedule: $e');
      setState(() {
        slots = [];
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
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header với các ngày trong tuần
          _buildWeekHeader(),

          // Main calendar content - timeline và events dùng chung scroll
          Expanded(child: _buildCalendarContent()),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    final now = DateTime.now();
    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    // Tạo list các ngày từ hôm nay trở đi (7 ngày)
    final dates = List.generate(7, (index) => now.add(Duration(days: index)));

    return Container(
      padding: const EdgeInsets.only(top: 80), // top 30
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          SizedBox(width: 20),
          ...List.generate(7, (index) {
            final currentDate = dates[index];
            final isSelected =
                currentDate.day == selectedDate.day &&
                currentDate.month == selectedDate.month &&
                currentDate.year == selectedDate.year;
            final isToday =
                currentDate.day == now.day &&
                currentDate.month == now.month &&
                currentDate.year == now.year;

            // Fix weekday calculation để tránh null
            final weekdayIndex =
                (currentDate.weekday == 7)
                    ? 0
                    : currentDate.weekday; // Sunday = 0

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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.blue
                                : (isToday
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.transparent),
                        shape: BoxShape.circle,
                        border:
                            isToday && !isSelected
                                ? Border.all(color: Colors.blue, width: 1)
                                : null,
                      ),
                      child: Center(
                        child: Text(
                          '${currentDate.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected
                                    ? Colors.white
                                    : (isToday ? Colors.blue : Colors.black),
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

  // Widget chính chứa timeline và events grid dùng chung scroll
  Widget _buildCalendarContent() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Loading events...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Lấy events cho ngày được chọn
    DateTime selectedDateKey = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final dayEvents = eventsByDate[selectedDateKey] ?? [];

    final sortedEvents = List<Task>.from(dayEvents)..sort(
      (a, b) => (a.startTime.hour * 60 + a.startTime.minute).compareTo(
        b.startTime.hour * 60 + b.startTime.minute,
      ),
    );

    return Column(
      children: [
        // Sticky button
        Container(
          padding: const EdgeInsets.all(2.0),
          color: Colors.white,
          child: Row(
            children: [
              // Nút Back (icon-only)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.blue),
              ),

              // Khoảng trống để đẩy nút giữa
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    // onPressed: () => _showAddEventDialog(),
                    onPressed: () => showConfirmationDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Make Appointment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

              // Placeholder để cân bằng (đảm bảo nút giữa thực sự ở giữa)
              const SizedBox(width: 48), // cùng width với IconButton
            ],
          ),
        ),

        const Divider(thickness: 2, color: Colors.grey, height: 10),

        // Scrollable calendar
        Expanded(
          child: SingleChildScrollView(
            controller: _mainScrollController,
            physics: ClampingScrollPhysics(),
            child: SizedBox(
              height: _displayHours * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: _buildEventsColumn(sortedEvents))],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsColumn(List<Task> dayEvents) {
    return Container(
      key: _gridContainerKey, // Thêm key vào đây
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: SizedBox(
        height: _displayHours * _hourHeight,
        child: Stack(
          children: [
            _buildGridBackground(),
            ...dayEvents.map((task) => _buildEventCard(task)).toList(),
          ],
        ),
      ),
    );
  }

  // Widget để vẽ background grid lưới - IMPROVED VERSION
  Widget _buildGridBackground() {
    return Stack(
      children: [
        // Background màu trắng cho toàn bộ grid
        Container(color: Colors.white),

        // Grid lines cho mỗi giờ - đậm và rõ ràng
        ...List.generate(_displayHours + 1, (index) {
          final isMajorHour = true; // Tất cả các giờ đều là major lines

          return Positioned(
            top: index * _hourHeight,
            left: 0,
            right: 0,
            child: Container(
              height: isMajorHour ? 1.5 : 1, // Line đậm hơn cho các giờ
              color: isMajorHour ? Colors.grey[400]! : Colors.grey[300]!,
            ),
          );
        }),

        // Grid lines cho mỗi 30 phút - medium weight
        ...List.generate(2 * _displayHours, (index) {
          if (index % 2 != 0) {
            // Line ở giữa mỗi giờ (30 phút)
            return Positioned(
              top: (index * _hourHeight / 2),
              left: 0,
              right: 0,
              child: Container(
                height: 1.0,
                color: Colors.grey[300]!.withOpacity(0.7),
              ),
            );
          }
          return SizedBox.shrink();
        }),

        // Grid lines cho mỗi 15 phút - nhạt nhất
        ...List.generate(4 * _displayHours, (index) {
          if (index % 4 != 0 && index % 2 != 0) {
            // Chỉ vẽ lines cho 15 và 45 phút
            return Positioned(
              top: (index * _hourHeight / 4),
              left: 0,
              right: 0,
              child: Container(height: 0.5, color: Colors.grey[200]!),
            );
          }
          return SizedBox.shrink();
        }),

        // Hiển thị nhãn giờ bên trong grid (tùy chọn)
        ...List.generate(_displayHours, (index) {
          final hour = _startHour + index;
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final period = hour < 12 ? 'AM' : 'PM';

          return Positioned(
            top: (index * _hourHeight) + 4,
            left: 8,
            child: Text(
              '${displayHour} ${period}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }),
      ],
    );
  }

  // Widget để render từng event card
  Widget _buildEventCard(Task task) {
    final startMinutes = task.startTime.hour * 60 + task.startTime.minute;
    final endMinutes = task.endTime.hour * 60 + task.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    final top = ((startMinutes / 60.0) - _startHour) * _hourHeight;
    final height = (durationMinutes / 60.0) * _hourHeight;

    if (top < 0 || top + height > _displayHours * _hourHeight) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: 60,
      right: 0,
      height: height.clamp(
        12.0,
        double.infinity,
      ), // Giảm min height từ 24 xuống 12 để tránh vượt line cho 15min cards
      child: GestureDetector(
        onTap: () {
          _showEventDetails(task);
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(
            horizontal: height > 40 ? 12 : 8,
            vertical: height > 40 ? 8 : 4,
          ),
          decoration: BoxDecoration(
            color: task.color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
            border: Border.all(color: task.color.withOpacity(0.3), width: 0.5),
          ),
          child: _buildEventCardContent(task, durationMinutes, height),
        ),
      ),
    );
  }

  // Nội dung của event card với responsive layout
  Widget _buildEventCardContent(
    Task task,
    int durationMinutes,
    double cardHeight,
  ) {
    if (task.taskCount == 1) {
      // Layout for 1 task: single line with name, time range, duration badge
      return Row(
        children: [
          Expanded(
            child: Text(
              task.fullName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${durationMinutes}m',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else {
      // Layout for >1 task: current column layout
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tên client
          Text(
            task.fullName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (cardHeight > 60) ...[
            SizedBox(height: 2),
            // Thông tin chi tiết
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.white.withOpacity(0.9),
                  size: 10,
                ),
                SizedBox(width: 4),
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

          Spacer(),

          // Services count và duration
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
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${durationMinutes}m',
                  style: TextStyle(
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

  void _showEventDetails(Task task) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(task.fullName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time: ${_formatTime(task.startTime)} - ${_formatTime(task.endTime)}',
                ),
                SizedBox(height: 8),
                Text(
                  'Estimate: ${task.taskCount} task${task.taskCount > 1 ? 's' : ''} (${task.taskCount * 15} minutes)',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  // Hàm kiểm tra trùng lịch
  bool _isTimeSlotAvailable(
    DateTime date,
    TimeOfDay startTime,
    int durationMinutes,
  ) {
    final dayEvents = eventsByDate[date] ?? [];

    final newStartMinutes = startTime.hour * 60 + startTime.minute;
    final newEndMinutes = newStartMinutes + durationMinutes;

    for (Task existingTask in dayEvents) {
      final existingStartMinutes =
          existingTask.startTime.hour * 60 + existingTask.startTime.minute;
      final existingEndMinutes =
          existingTask.endTime.hour * 60 + existingTask.endTime.minute;

      bool hasOverlap =
          (newStartMinutes < existingEndMinutes) &&
          (newEndMinutes > existingStartMinutes);

      if (hasOverlap) {
        return false;
      }
    }

    return true;
  }

  void showConfirmationDialog() {
    // Tính toán thời gian dựa trên số service
    final int selectedTaskCount = widget.serviceNames.length;
    final int durationMinutes = selectedTaskCount * 15; // Mỗi service 15 phút

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Local state for the dialog
        final TextEditingController phoneController = TextEditingController();
        final FocusNode phoneFocusNode = FocusNode();
        String phoneError = '';
        bool isPhoneValid = false;
        bool localAgreedMarketing = agreedMarketing;
        bool showAllPhones = false;

        // Biến cho phần thời gian
        TimeOfDay? selectedStartTime = TimeOfDay(hour: 9, minute: 0);
        TimeOfDay? calculatedEndTime;

        // Tính toán end time dựa trên start time và số service
        TimeOfDay calculateEndTime(TimeOfDay start, int taskCount) {
          int totalMinutes = start.hour * 60 + start.minute + taskCount * 15;
          int endHour = (totalMinutes ~/ 60) % 24;
          int endMinute = totalMinutes % 60;
          return TimeOfDay(hour: endHour, minute: endMinute);
        }

        // Kiểm tra time slot có available không
        bool _isTimeSlotAvailable(
          DateTime date,
          TimeOfDay startTime,
          int duration,
        ) {
          final dateKey = DateTime(date.year, date.month, date.day);
          final events = eventsByDate[dateKey] ?? [];

          final startTotalMinutes = startTime.hour * 60 + startTime.minute;
          final endTotalMinutes = startTotalMinutes + duration;

          for (final event in events) {
            final eventStart =
                event.startTime.hour * 60 + event.startTime.minute;
            final eventEnd = event.endTime.hour * 60 + event.endTime.minute;

            if (startTotalMinutes < eventEnd && endTotalMinutes > eventStart) {
              return false; // Overlap detected
            }
          }
          return true;
        }

        void validatePhoneNumber(String phone) {
          final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

          if (cleanedPhone.isEmpty) {
            phoneError = 'Phone number is required';
            isPhoneValid = false;
            return;
          }

          if (cleanedPhone.length != 11) {
            phoneError = 'Phone number must be 10 digits (not include +1)';
            isPhoneValid = false;
            return;
          }

          // Basic validation for US phone number
          final areaCode = int.parse(cleanedPhone.substring(1, 4));

          if (areaCode < 200 || areaCode > 999) {
            phoneError = 'Invalid area code';
            isPhoneValid = false;
            return;
          }

          phoneError = '';
          isPhoneValid = true;
        }

        // Pre-fill with primary phone if available
        if (primaryPhoneNumber != null) {
          phoneController.text = primaryPhoneNumber!.formattedPhone;
          validatePhoneNumber(primaryPhoneNumber!.phoneNumber);
        }

        // Tính toán end time ban đầu
        if (selectedStartTime != null) {
          calculatedEndTime = calculateEndTime(
            selectedStartTime!,
            selectedTaskCount,
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Cập nhật end time khi state thay đổi
            if (selectedStartTime != null) {
              calculatedEndTime = calculateEndTime(
                selectedStartTime!,
                selectedTaskCount,
              );
            }

            final dateKey = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
            );
            final isAvailable =
                selectedStartTime != null
                    ? _isTimeSlotAvailable(
                      dateKey,
                      selectedStartTime!,
                      durationMinutes,
                    )
                    : false;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.calendar_today, color: AppColors.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    "Appointment confirm",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "Beauty Specialist: ${widget.staffName}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Service names: ${widget.serviceNames.join(', ')}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),

                    // Phần chọn thời gian
                    Row(
                      children: [
                        const Text("Time: "),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final TimeOfDay? picked =
                                  await showDialog<TimeOfDay>(
                                    context: context,
                                    builder:
                                        (context) => CustomTimePickerDialog(
                                          initialTime:
                                              selectedStartTime ??
                                              TimeOfDay(hour: 9, minute: 0),
                                          onTimeChanged: (time) {
                                            setDialogState(() {
                                              selectedStartTime = time;
                                            });
                                          },
                                        ),
                                  );

                              if (picked != null) {
                                final totalMinutes =
                                    picked.hour * 60 + picked.minute;
                                if (totalMinutes >= 9 * 60 &&
                                    totalMinutes <= 19 * 60) {
                                  bool isFuture = true;
                                  final now = DateTime.now();
                                  if (selectedDate.year == now.year &&
                                      selectedDate.month == now.month &&
                                      selectedDate.day == now.day) {
                                    final currentTotalMinutes =
                                        now.hour * 60 + now.minute;
                                    if (totalMinutes <= currentTotalMinutes) {
                                      isFuture = false;
                                    }
                                  }

                                  if (isFuture) {
                                    setDialogState(() {
                                      selectedStartTime = picked;
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select a future time.',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Time must be between 9:00 AM and 7:00 PM.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedStartTime != null
                                        ? selectedStartTime!.format(context)
                                        : 'Select time',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Icon(Icons.access_time),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hiển thị thông tin thời gian
                    if (selectedStartTime != null &&
                        calculatedEndTime != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              isAvailable
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAvailable ? Colors.green : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${selectedStartTime!.format(context)} - ${calculatedEndTime!.format(context)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "Estimated: $durationMinutes mins",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Please select a start time.",
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // PHẦN HIỂN THỊ DANH SÁCH SỐ ĐIỆN THOẠI ĐÃ LƯU
                    if (savedPhoneNumbers.isNotEmpty) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!showAllPhones) ...[
                            if (primaryPhoneNumber != null)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.porcelainColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.greenColor,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      showAllPhones = true;
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        primaryPhoneNumber!.formattedPhone,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Text(
                                            "Primary",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.greenColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (savedPhoneNumbers.length > 1) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_drop_down,
                                              size: 16,
                                              color: AppColors.greenColor,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ] else ...[
                            // Hiển thị tất cả số điện thoại
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.porcelainColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.greenColor),
                              ),
                              child: Column(
                                children: [
                                  // Dòng mặc định (Primary)
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        showAllPhones = !showAllPhones;
                                      });
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          primaryPhoneNumber!.formattedPhone,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Text(
                                              "Primary",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.greenColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              showAllPhones
                                                  ? Icons.arrow_drop_up
                                                  : Icons.arrow_drop_down,
                                              size: 16,
                                              color: AppColors.greenColor,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Nếu mở dropdown thì render danh sách
                                  if (showAllPhones) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      height:
                                          120, // hiển thị tối đa 3 số, scroll nếu nhiều hơn
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children:
                                          // Trong phần hiển thị tất cả số điện thoại (showAllPhones == true)
                                          savedPhoneNumbers.map((phone) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Colors.grey[300]!,
                                                    width: 0.5,
                                                  ),
                                                ),
                                              ),
                                              child: InkWell( // Thêm InkWell để có thể click
                                                onTap: () {
                                                  // Tự động nhập số điện thoại vào input
                                                  phoneController.text = phone.formattedPhone;
                                                  validatePhoneNumber(phone.phoneNumber);
                                                  setDialogState(() {
                                                    showAllPhones = false; // Đóng dropdown sau khi chọn
                                                  });
                                                },
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Số điện thoại + Primary
                                                    Row(
                                                      children: [
                                                        Text(
                                                          phone.formattedPhone,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: phone.isPrimary ? FontWeight.bold : FontWeight.normal,
                                                          ),
                                                        ),
                                                        if (phone.isPrimary) ...[
                                                          const SizedBox(width: 6),
                                                          const Text(
                                                            "Primary",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: AppColors.primaryColor,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),

                                                    // Nút SetPrimary + Delete (chỉ hiện khi không phải primary)
                                                    if (!phone.isPrimary)
                                                      Row(
                                                        children: [
                                                          InkWell(
                                                            onTap: () async {
                                                              await setPrimaryPhoneNumber(phone.id);
                                                              setDialogState(() {});
                                                            },
                                                            child: const Padding(
                                                              padding: EdgeInsets.all(4),
                                                              child: Icon(Icons.star_border, size: 16),
                                                            ),
                                                          ),
                                                          InkWell(
                                                            onTap: () async {
                                                              await deletePhoneNumber(phone.id);
                                                              setDialogState(() {});
                                                            },
                                                            child: const Padding(
                                                              padding: EdgeInsets.all(4),
                                                              child: Icon(Icons.delete_outline, size: 16),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 12),
                    ],

                    // Phone number input
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: phoneController,
                            focusNode: phoneFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Phone Number *',
                              hintText: '+1 (XXX) XXX-XXXX',
                              errorText:
                                  phoneError.isNotEmpty ? phoneError : null,
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            onChanged: (value) {
                              final digits = value.replaceAll(
                                RegExp(r'[^\d]'),
                                '',
                              );
                              if (digits.length > 11) {
                                final trimmedDigits = digits.substring(0, 11);
                                phoneController.text = _formatPhoneNumber(
                                  trimmedDigits,
                                );
                                phoneController
                                    .selection = TextSelection.collapsed(
                                  offset: phoneController.text.length,
                                );
                                validatePhoneNumber(trimmedDigits);
                                setDialogState(() {});
                                return;
                              }

                              final formatted = _formatPhoneNumber(digits);
                              if (formatted != phoneController.text) {
                                phoneController.text = formatted;
                                phoneController
                                    .selection = TextSelection.collapsed(
                                  offset: formatted.length,
                                );
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
                            final cleanedPhone = phoneController.text
                                .replaceAll(RegExp(r'[^\d]'), '');
                            if (cleanedPhone.length == 11) {
                              await savePhoneNumber(cleanedPhone);
                              setDialogState(() {
                                showAllPhones = false;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Checkbox(
                          value: localAgreedMarketing,
                          activeColor: AppColors.primaryColor,
                          onChanged: (val) {
                            setDialogState(() {
                              localAgreedMarketing = val ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            "I consent to receive marketing and notification SMS messages.",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
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
                  onPressed:
                      isCreatingBooking
                          ? null
                          : () => Navigator.pop(dialogContext),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    backgroundColor:
                        (localAgreedMarketing &&
                                isPhoneValid &&
                                !isCreatingBooking &&
                                selectedStartTime != null &&
                                isAvailable)
                            ? AppColors.primaryColor
                            : AppColors.porcelainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      (localAgreedMarketing &&
                              isPhoneValid &&
                              !isCreatingBooking &&
                              selectedStartTime != null &&
                              isAvailable)
                          ? () async {
                            // Set loading state
                            setState(() {
                              isCreatingBooking = true;
                            });
                            setDialogState(() {}); // Update dialog UI

                            agreedMarketing = localAgreedMarketing;

                            int? userId = await ApiService.getUserId();
                            String customerPhone = phoneController.text
                                .replaceAll(RegExp(r'[^\d]'), '');

                            // Sử dụng selectedStartTime từ dialog
                            final DateTime bookingDateTime = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedStartTime!.hour,
                              selectedStartTime!.minute,
                            );

                            String startTimeStr = DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(bookingDateTime);

                            final res = await ApiService.createBooking(
                              staffId: widget.staffId,
                              customerId: userId!,
                              customerPhone: customerPhone,
                              startTime: startTimeStr,
                              storeId: widget.storeId,
                              serviceIds: widget.serviceIds,
                            );

                            if (!mounted) return;

                            // Handle the response immediately
                            if (res['success'] == true) {
                              // Refetch schedule để cập nhật events mới
                              await fetchSchedule();

                              // Reset state immediately
                              setState(() {
                                selectedSlot = null;
                                selectedSlotStartTime = null;
                                remainingSeconds = 0;
                                countdownTimer?.cancel();
                                isCreatingBooking = false;
                              });

                              // Close dialog immediately
                              Navigator.of(dialogContext).pop();

                              // Show success message
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
                                          res['message'] ??
                                              "Booking successful",
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );

                              // Navigate back to main screen and switch to booking tab
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          BottomNavBarView(initialTabIndex: 2),
                                ),
                                (route) => false,
                              );
                            } else {
                              // Error handling
                              setState(() {
                                isCreatingBooking = false;
                              });
                              setDialogState(() {});

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.error,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          res['message'] ?? "Booking failed",
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                          : null,
                  child:
                      isCreatingBooking
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.whiteColor,
                              ),
                            ),
                          )
                          : const Text(
                            "Confirm",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.whiteColor,
                            ),
                          ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          isCreatingBooking = false;
        });
      }
    });
  }
}

class Task {
  final String fullName;
  final Color color;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int taskCount; // Số lượng tasks (1 task = 15 phút)

  Task({
    required this.fullName,
    required this.color,
    required this.startTime,
    required this.endTime,
    this.taskCount = 2, // Mặc định 2 tasks = 30 phút
  });
}
