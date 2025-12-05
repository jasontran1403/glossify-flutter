import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/view/receptionist_screen/task_model.dart';
import 'package:hair_sallon/view/receptionist_screen/time_picker.dart';
import 'package:intl/intl.dart';

import '../../api/api_service.dart';
import '../../api/staff_schedule_model.dart';
import '../../utils/app_colors/app_colors.dart';
import '../home_screen/detail_stylist.dart';

class ScheduleCalendarScreen extends StatefulWidget {
  final int storeId;
  final List<int> serviceIds;
  final List<String> serviceNames;
  final int? userId; // Add this line

  const ScheduleCalendarScreen({
    super.key,
    required this.storeId,
    this.serviceIds = const [],
    this.serviceNames = const [],
    this.userId, // Add this line
  });

  @override
  State<ScheduleCalendarScreen> createState() => _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState extends State<ScheduleCalendarScreen> {
  DateTime selectedDate = DateTime.now();
  Timer? _currentTimeTimer; // Thêm dòng này

  List<ServiceModel> selectedServices = [];
  int? selectedStaffIdForBooking;
  DateTime? selectedTimeForBooking;

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final double _hourHeight = 120.0;
  final double _timeColumnWidth = 90.0;
  bool isLoading = false;
  bool agreedMarketing = false;

  // ADD THIS LINE - the missing flag
  bool _isSyncing = false;

  List<StaffSchedule> staffSchedules = [];
  Map<int, List<Task>> eventsByStaffId = {};

  Task? selectedSlot;
  String? selectedSlotStartTime;

  bool isCreatingBooking = false; // NEW: Track booking creation state
  final int _startHour = 7;
  final int _displayHours = 12;

  String? errorMessage;
  Timer? countdownTimer;
  int remainingSeconds = 0;

  Map<DateTime, List<Task>> eventsByDate = {}; // Legacy, may not need

  final DateFormat _dateFormat = DateFormat('MMMM EEE dd, yyyy');

  final ScrollController _staffHeaderScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _mainScrollController.addListener(_onMainScroll);

    // Đồng bộ scroll ngang giữa header và content
    _horizontalScrollController.addListener(() {
      if (_horizontalScrollController.hasClients && _staffHeaderScrollController.hasClients) {
        if (!_isSyncing) {
          _isSyncing = true;
          _staffHeaderScrollController.jumpTo(_horizontalScrollController.offset);
          _isSyncing = false;
        }
      }
    });

    _staffHeaderScrollController.addListener(() {
      if (_horizontalScrollController.hasClients && _staffHeaderScrollController.hasClients) {
        if (!_isSyncing) {
          _isSyncing = true;
          _horizontalScrollController.jumpTo(_staffHeaderScrollController.offset);
          _isSyncing = false;
        }
      }
    });

    // TIMER ĐỂ CẬP NHẬT REAL-TIME MỖI GIÂY
    _currentTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Force rebuild để cập nhật vị trí đường thời gian và label
        });
      }
    });

    fetchSchedule();
  }

  (double? position, String? timeLabel) _getCurrentTimeLinePosition() {
    final now = DateTime.now();

    // Chỉ hiển thị đường thời gian nếu selectedDate là ngày hôm nay
    if (selectedDate.year != now.year ||
        selectedDate.month != now.month ||
        selectedDate.day != now.day) {
      return (null, null);
    }

    final currentTime = TimeOfDay.fromDateTime(now);
    final currentTotalMinutes = currentTime.hour * 60 + currentTime.minute;
    final startTotalMinutes = _startHour * 60;

    // Tính vị trí dựa trên thời gian hiện tại
    if (currentTotalMinutes >= startTotalMinutes &&
        currentTotalMinutes <= (_startHour + _displayHours) * 60) {
      final minutesFromStart = currentTotalMinutes - startTotalMinutes;
      final position = (minutesFromStart / 60.0) * _hourHeight;

      // Format time label: hh:mm:ss
      final timeLabel = DateFormat('HH:mm:ss').format(now);

      return (position, timeLabel);
    }

    return (null, null);
  }

  bool _isTimeSlotAvailableForBooking(DateTime dateTime) {
    final now = DateTime.now();

    // Nếu không phải ngày hôm nay, cho phép đặt bất kỳ thời gian nào
    if (dateTime.year != now.year || dateTime.month != now.month || dateTime.day != now.day) {
      return true;
    }

    // Nếu là ngày hôm nay, chỉ cho phép đặt thời gian trong tương lai
    return dateTime.isAfter(now);
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

    // Lưu thông tin để dùng sau
    selectedStaffIdForBooking = schedule.staffId;
    selectedTimeForBooking = clickedDateTime;

    // Hiển thị service selection bottom sheet
    _showServiceSelectionSheet(schedule);
  }

  Future<void> _showServiceSelectionSheet(StaffSchedule schedule) async {
    // Reset selected services
    selectedServices.clear();

    // Fetch staff services
    List<ServiceModel> staffServices = [];
    bool isLoading = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Fetch services nếu chưa load
            if (isLoading) {
              ApiService.getStaffDetailForReceptionist(schedule.staffId).then((staffDetail) {
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
              height: MediaQuery.of(context).size.height * 0.6, // CỐ ĐỊNH 30% CHIỀU CAO
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 80,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                  // Service list - CHO PHÉP SCROLL
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: staffServices.length,
                      itemBuilder: (context, index) {
                        final service = staffServices[index];
                        final isSelected = selectedServices
                            .any((s) => s.id == service.id);

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
                              backgroundImage: service.avatar.isNotEmpty
                                  ? NetworkImage(service.avatar)
                                  : null,
                              child: service.avatar.isEmpty
                                  ? const Icon(Icons.content_cut, size: 20)
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
                              '\$${service.price.toStringAsFixed(2)} • 15 min',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: selectedServices.length >= 6 && !isSelected
                                  ? null
                                  : (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selectedServices.add(service);
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
                              if (selectedServices.length < 6 || isSelected) {
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

                  // Next button - CỐ ĐỊNH Ở DƯỚI
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
    // Handle main scroll if needed
  }

  void _onHorizontalScroll() {
    if (_isSyncing) return;
    // Handle horizontal scroll if needed
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

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

  Future<void> fetchSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getAllStaffSchedule(storeId: widget.storeId,type: 0, date: selectedDate);

      if (data.isEmpty) {
        setState(() {
          staffSchedules = [];
          eventsByStaffId.clear();
          errorMessage = "Không có nhân viên nào trong ngày này.";
          final dateKey = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
          );
          eventsByDate[dateKey] = [];
        });
      } else {
        // Process events per staff
        Map<int, List<Task>> tempEventsByStaff = {};
        final List<Color> colors = [
          Colors.blue,
          Colors.purple,
          Colors.green,
          Colors.orange,
          Colors.red,
        ];

        for (var schedule in data) {
          List<Task> staffEvents = [];
          if (schedule.fullName == "Anyone") continue;

          for (var slot in schedule.slots) {
            final startTime = _parseTime(slot.startTime);
            final endTime = _parseTime(slot.endTime);
            final color = colors[slot.services % colors.length];
            final task = Task(
              bookingId: slot.bookingId,
              fullName: slot.fullName, // Customer name
              customerAvt: slot.customerAvt,
              staffName: slot.fullName,
              startTime: startTime,
              endTime: endTime,
              status: slot.status,
              taskCount: slot.services,
            );
            staffEvents.add(task);
          }
          tempEventsByStaff[schedule.staffId] = staffEvents;
        }

        final dateKey = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        setState(() {
          staffSchedules = data;
          eventsByStaffId = tempEventsByStaff;
          eventsByDate[dateKey] = []; // Legacy
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
        staffSchedules = [];
        eventsByStaffId.clear();
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
    final today = DateTime.now();
    if (selectedDate.isAfter(today)) {
      setState(() {
        selectedDate = selectedDate.subtract(const Duration(days: 1));
      });
      fetchSchedule();
    }
  }

  void _goToNextDay() {
    final maxDate = DateTime.now().add(const Duration(days: 14));
    if (selectedDate.isBefore(maxDate)) {
      setState(() {
        selectedDate = selectedDate.add(const Duration(days: 1));
      });
      fetchSchedule();
    }
  }

  void _goToToday() {
    final today = DateTime.now();
    if (!selectedDate.isAtSameMomentAs(today)) {
      setState(() {
        selectedDate = today;
      });
      fetchSchedule();
    }
  }

  Future<void> _showDatePicker() async {
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
    _currentTimeTimer?.cancel(); // SỬA LỖI Ở ĐÂY - ĐÃ CÓ KHAI BÁO _currentTimeTimer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - _timeColumnWidth - 32;
    final int maxVisibleStaff = 4;
    final double staffColumnWidth = staffSchedules.isEmpty
        ? 180.0
        : availableWidth / (staffSchedules.length > maxVisibleStaff ? maxVisibleStaff : staffSchedules.length);

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
        // FIXED HEADER SECTION - scroll với controller riêng
        Row(
          children: [
            SizedBox(width: _timeColumnWidth),
            Expanded(
              child: SingleChildScrollView(
                controller: _staffHeaderScrollController, // SỬ DỤNG CONTROLLER RIÊNG
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: staffSchedules.map((schedule) => Container(
                    width: staffColumnWidth,
                    height: 100,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: schedule.avatar.isNotEmpty
                              ? NetworkImage(schedule.avatar)
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          child: (schedule.avatar.isEmpty)
                              ? const Icon(Icons.person, size: 30, color: Colors.grey)
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
                  )).toList(),
                ),
              ),
            ),
          ],
        ),

        // SCROLLABLE CONTENT - giữ nguyên với _horizontalScrollController
        // SCROLLABLE CONTENT - giữ nguyên với _horizontalScrollController
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
                                  // THÊM ĐƯỜNG THỜI GIAN HIỆN TẠI VÀO ĐÂY
                                  _buildCurrentTimeLine(),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: staffSchedules.map((schedule) {
                                      return _buildStaffColumn(schedule, staffColumnWidth);
                                    }).toList(),
                                  ),
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
        clipBehavior: Clip.none, // QUAN TRỌNG: Cho phép các widget con vượt ra ngoài bounds
        children: [
          // ĐƯỜNG THỜI GIAN
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

          // DOT INDICATOR
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

          // LABEL THỜI GIAN - SỬ DỤNG TRANSFORM ĐỂ ĐẨY LÊN TRÊN
          Positioned(
            left: _timeColumnWidth,
            top: 14, // Vị trí gốc là tại line
            child: Transform.translate(
              offset: const Offset(0, -30), // Đẩy label lên trên 30px
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
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
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
    final today = DateTime.now();
    final isTodaySelected = selectedDate.isAtSameMomentAs(today);
    final dateLabel = _dateFormat.format(selectedDate);

    return Container(
      padding: const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // ✅ NEW — BACK BUTTON
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

          // Today button
          GestureDetector(
            onTap: isLoading ? null : _goToToday,
            child: Opacity(
              opacity: isLoading ? 0.5 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isTodaySelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isTodaySelected ? Border.all(color: Colors.blue, width: 1) : null,
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

          // Refresh
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

          // Previous
          IconButton(
            onPressed: isLoading ? null : _goToPreviousDay,
            icon: Icon(
                Icons.chevron_left,
                color: isLoading ? Colors.grey : Colors.blue
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),

          // Date picker
          Expanded(
            child: GestureDetector(
              onTap: isLoading ? null : _showDatePicker,
              child: Opacity(
                opacity: isLoading ? 0.5 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Row(
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
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Next
          IconButton(
            onPressed: isLoading ? null : _goToNextDay,
            icon: Icon(
                Icons.chevron_right,
                color: isLoading ? Colors.grey : Colors.blue
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

  // Horizontal grid lines (full width, all minor lines)
  Widget _buildHorizontalGridLines() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Major lines (every hour) - ĐẬM HƠN
          ...List.generate(_displayHours + 1, (index) {
            return Positioned(
              top: index * _hourHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 2.0, // Tăng từ 1.5 lên 2.0
                color: Colors.grey[500]!, // Đậm hơn từ grey[400] lên grey[500]
              ),
            );
          }),

          // 30-min lines - ĐẬM HƠN
          ...List.generate(_displayHours, (index) {
            return Positioned(
              top: (index * _hourHeight) + (_hourHeight / 2),
              left: 0,
              right: 0,
              child: Container(
                height: 1.5, // Tăng từ 1.0 lên 1.5
                color: Colors.grey[400]!, // Đậm hơn
              ),
            );
          }),

          // 15-min lines (GIỮ NHẸ)
          ...List.generate(4 * _displayHours, (index) {
            // Bỏ qua giờ chẵn (index % 4 == 0) và phút 30 (index % 2 == 0)
            if (index % 4 != 0 && index % 2 != 0) {
              return Positioned(
                top: (index * _hourHeight / 4),
                left: 0,
                right: 0,
                child: Container(
                  height: 0.5,
                  color: Colors.grey[200]!,
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  // Time labels (left column) - CẢI TIẾN: Thêm label cho 30 phút
  Widget _buildTimeLabels() {
    return Stack(
      children: [
        // Labels cho giờ chẵn (7 AM, 8 AM, 9 AM,...)
        ...List.generate(_displayHours, (index) {
          final hour = _startHour + index;
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final period = hour < 12 ? 'AM' : 'PM';

          return Positioned(
            top: (index * _hourHeight) - 8, // Dịch lên 8px để căn giữa với line
            left: 8,
            child: Text(
              '$displayHour:00 $period',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),

        // Labels cho phút 30 (7:30 AM, 8:30 AM,...)
        ...List.generate(_displayHours, (index) {
          final hour = _startHour + index;
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final period = hour < 12 ? 'AM' : 'PM';

          return Positioned(
            top: (index * _hourHeight + _hourHeight / 2) - 6, // Vị trí 30 phút, dịch lên 8px
            left: 8,
            child: Text(
              '$displayHour:30 $period',
              style: TextStyle(
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
    final sortedEvents = List<Task>.from(events)
      ..sort((a, b) => (a.startTime.hour * 60 + a.startTime.minute)
          .compareTo(b.startTime.hour * 60 + b.startTime.minute));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) {
        _onStaffColumnTap(schedule, details.localPosition);
      },
      child: Container(
        width: staffColumnWidth,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.grey[300]!, width: 1)),
        ),
        child: Stack(
          children: sortedEvents
              .map((task) => _buildEventCard(task, schedule.fullName))
              .toList(),
        ),
      ),
    );
  }

  // Widget để render từng event card (per staff column)
  Widget _buildEventCard(Task task, String staffName) {
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
      left: 0,
      right: 0,
      height: height.clamp(12.0, double.infinity),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Đổi lại opaque để chặn long press
        onTap: () {
          _showEventDetails(task, staffName);
        },
        onLongPress: () {
          // THÊM DÒNG NÀY - Long press cũng hiển thị event details
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
            border: Border.all(
                color: Colors.blue.withOpacity(0.3), width: 0.5),
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
      // Layout for >1 task: current column layout
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tên client
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
            // Thông tin chi tiết
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
              'Estimate: ${task.taskCount} service${task.taskCount > 1 ? 's' : ''} (${task.taskCount * 15} minutes)',
            ),
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

    final int durationMinutes = selectedServices.length * 15;
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
            final eventStart = event.startTime.hour * 60 + event.startTime.minute;
            final eventEnd = event.endTime.hour * 60 + event.endTime.minute;

            if (startTotalMinutes < eventEnd && endTotalMinutes > eventStart) {
              return false;
            }
          }
          return true;
        }

        calculatedEndTime = calculateEndTime(startTime, durationMinutes);
        final isAvailable = _isTimeSlotAvailable(
          schedule.staffId,
          selectedDate,
          startTime,
          durationMinutes,
        );

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
                      ...selectedServices.map((service) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                service.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '\$${service.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAvailable ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                    "Estimated: $durationMinutes mins",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (!isAvailable) ...[
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

                      if (!isAvailable) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Suggested: Choose a time before or after the existing appointments.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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
                    backgroundColor: (!isCreatingBooking && isAvailable)
                        ? AppColors.primaryColor
                        : AppColors.porcelainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (!isCreatingBooking && isAvailable)
                      ? () async {
                    setState(() {
                      isCreatingBooking = true;
                    });

                    setDialogState(() {});

                    String startTimeStr = DateFormat('yyyy-MM-dd HH:mm')
                        .format(selectedTimeForBooking!);

                    final res = await ApiService.receptionistCreateBooking(
                      staffId: schedule.staffId,
                      customerId: widget.userId!,
                      customerPhone: '10000000000',
                      startTime: startTimeStr,
                      storeId: widget.storeId,
                      serviceIds: selectedServices.map((s) => s.id).toList(),
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
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
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

                      // ✅ MODIFIED: Navigate back to FrontDeskWelcomeScreen
                      // Pop back to the previous screen (FrontDeskWelcomeScreen)
                      Navigator.of(context).pop();

                    } else {
                      setState(() {
                        isCreatingBooking = false;
                      });
                      setDialogState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message'] ?? "Booking failed"),
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
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text(
                    "Confirm",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
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

  void showConfirmationDialog() {
    // Tính toán thời gian dựa trên số service
    final int selectedTaskCount = widget.serviceNames.length;
    final int durationMinutes = selectedTaskCount * 15; // Mỗi service 15 phút

    // Initial staff selection (first staff)
    final int? initialStaffId = staffSchedules.isNotEmpty ? staffSchedules.first.staffId : null;
    String? selectedStaffName = staffSchedules.isNotEmpty ? staffSchedules.first.fullName : null;
    int? selectedStaffId = initialStaffId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Local state for the dialog
        String phoneError = '';
        bool isPhoneValid = false;
        bool localAgreedMarketing = agreedMarketing;
        TimeOfDay? selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
        TimeOfDay? calculatedEndTime;

        // Tính toán end time dựa trên start time và số service
        TimeOfDay calculateEndTime(TimeOfDay start, int taskCount) {
          int totalMinutes = start.hour * 60 + start.minute + taskCount * 15;
          int endHour = (totalMinutes ~/ 60) % 24;
          int endMinute = totalMinutes % 60;
          return TimeOfDay(hour: endHour, minute: endMinute);
        }

        // Kiểm tra time slot có available không per staff
        bool _isTimeSlotAvailableLocal(
            int? staffId,
            DateTime date,
            TimeOfDay startTime,
            int duration,
            ) {
          if (staffId == null) return false;
          final dateKey = DateTime(date.year, date.month, date.day);
          final events = eventsByStaffId[staffId] ?? [];

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

        final TextEditingController phoneController = TextEditingController();
        phoneController.text = ''; // Default empty for walk-in

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
            final isAvailable = selectedStartTime != null && selectedStaffId != null
                ? _isTimeSlotAvailableLocal(
              selectedStaffId,
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
              title: const Row(
                children: [
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
                    // Staff selection dropdown
                    DropdownButtonFormField<int>(
                      value: selectedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Beauty Specialist *',
                        border: OutlineInputBorder(),
                      ),
                      items: staffSchedules.map((schedule) {
                        return DropdownMenuItem<int>(
                          value: schedule.staffId,
                          child: Text(schedule.fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStaffId = value;
                          selectedStaffName = staffSchedules
                              .firstWhere((s) => s.staffId == value)
                              .fullName;
                        });
                      },
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
                                builder: (context) => CustomTimePickerDialog(
                                  initialTime:
                                  selectedStartTime ??
                                      const TimeOfDay(hour: 9, minute: 0),
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
                                        'Time must be between 7:00 AM and 7:00 PM.',
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
                        calculatedEndTime != null &&
                        selectedStaffId != null) ...[
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
                          "Please select a staff and start time.",
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Phone number input (simplified for walk-in)
                    TextFormField(
                      controller: phoneController,
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
                        selectedStaffId != null &&
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
                      selectedStaffId != null &&
                      isAvailable)
                      ? () async {
                    // Set loading state
                    setState(() {
                      isCreatingBooking = true;
                    });
                    setDialogState(() {}); // Update dialog UI

                    agreedMarketing = localAgreedMarketing;

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
                      staffId: selectedStaffId!, // Use selected staff
                      customerId: widget.userId!, // Hardcoded for walk-in
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

                      // ✅ MODIFIED: Navigate back to FrontDeskWelcomeScreen
                      // Pop back to the previous screen (FrontDeskWelcomeScreen)
                      Navigator.of(context).pop();

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