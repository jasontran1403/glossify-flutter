import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../api/api_service.dart';
import '../../utils/constant/staff_slot.dart';
import '../../utils/app_colors/app_colors.dart';
import '../bottombar_screen/bottomscreen_view_user.dart';
import 'bokking_upcoming_screen.dart';

class BookingScheduleScreen extends StatefulWidget {
  final int staffId;
  final String staffName;
  final List<int> serviceIds;
  final List<String> serviceNames;
  final int storeId;

  const BookingScheduleScreen({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.serviceIds,
    required this.serviceNames,
    required this.storeId,
  });

  @override
  State<BookingScheduleScreen> createState() => _BookingScheduleScreenState();
}

class _BookingScheduleScreenState extends State<BookingScheduleScreen> {
  DateTime selectedDate = DateTime.now();
  List<StaffSlot> slots = [];
  StaffSlot? selectedSlot;
  String? selectedSlotStartTime;
  bool isLoading = false;
  bool isCreatingBooking = false;
  String? errorMessage;
  Timer? countdownTimer;
  int remainingSeconds = 0;
  bool agreedMarketing = false;
  final DateRangePickerController _datePickerController =
  DateRangePickerController();

  List<PhoneNumber> savedPhoneNumbers = [];
  PhoneNumber? primaryPhoneNumber;
  bool isExpanded = false;
  bool isLoadingPhones = false;

  @override
  void initState() {
    super.initState();
    _datePickerController.displayDate = selectedDate;
    fetchSchedule();
    fetchSavedPhoneNumbers();
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

  @override
  void dispose() {
    countdownTimer?.cancel();
    _datePickerController.dispose();
    super.dispose();
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
        });
      } else {
        setState(() {
          slots = data;
          errorMessage = null;
          selectedSlot = null;
          selectedSlotStartTime = null;
          remainingSeconds = 0;
          countdownTimer?.cancel();
        });
      }
    } catch (e) {
      setState(() {
        slots = [];
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

  // ⭐ SỬA: Generate time slots với StaffSlot model mới
  List<DisplaySlot> generateTimeSlots(List<StaffSlot> slots) {
    List<DisplaySlot> formattedSlots = [];
    for (var slot in slots) {
      final start = DateFormat('HH:mm').parse(slot.startTime);
      final end = start.add(const Duration(minutes: 15));

      formattedSlots.add(
        DisplaySlot(
          startTime: slot.startTime,
          endTime: DateFormat('HH:mm').format(end),
          status: slot.status,
          displayTime:
          "${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}",
          originalSlot: slot, // ⭐ Giữ reference đến slot gốc
        ),
      );
    }
    return formattedSlots;
  }

  void showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final TextEditingController phoneController = TextEditingController();
        final FocusNode phoneFocusNode = FocusNode();
        String phoneError = '';
        bool isPhoneValid = false;
        bool localAgreedMarketing = agreedMarketing;
        bool showAllPhones = false;

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

          final areaCode = int.parse(cleanedPhone.substring(1, 4));

          if (areaCode < 200 || areaCode > 999) {
            phoneError = 'Invalid area code';
            isPhoneValid = false;
            return;
          }

          phoneError = '';
          isPhoneValid = true;
        }

        if (primaryPhoneNumber != null) {
          phoneController.text = primaryPhoneNumber!.formattedPhone;
          validatePhoneNumber(primaryPhoneNumber!.phoneNumber);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      "Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Time: ${selectedSlot != null ? "${selectedSlot!.startTime} - ${selectedSlot!.endTime}" : ''}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Service names: ${widget.serviceNames.join(', ')}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),

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
                                borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 12),
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
                        !isCreatingBooking)
                        ? AppColors.primaryColor
                        : AppColors.porcelainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                  (localAgreedMarketing &&
                      isPhoneValid &&
                      !isCreatingBooking)
                      ? () async {
                    setState(() {
                      isCreatingBooking = true;
                    });
                    setDialogState(() {});

                    agreedMarketing = localAgreedMarketing;

                    int? userId = await ApiService.getUserId();
                    String customerPhone = phoneController.text
                        .replaceAll(RegExp(r'[^\d]'), '');

                    final DateTime bookingDateTime = DateFormat(
                      "yyyy-MM-dd HH:mm",
                    ).parse(
                      "${DateFormat('yyyy-MM-dd').format(selectedDate)} $selectedSlotStartTime",
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
                      markUnchange: false,
                      serviceIds: widget.serviceIds,
                    );

                    if (!mounted) return;

                    if (res['success'] == true) {
                      setState(() {
                        selectedSlot = null;
                        selectedSlotStartTime = null;
                        remainingSeconds = 0;
                        countdownTimer?.cancel();
                        isCreatingBooking = false;
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

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder:
                              (context) =>
                              BottomNavBarView(initialTabIndex: 2),
                        ),
                            (route) => false,
                      );
                    } else {
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

  @override
  Widget build(BuildContext context) {
    final formattedSlots = generateTimeSlots(slots);

    return Scaffold(
      appBar: AppBar(title: Text("Schedule - ${widget.staffName}")),
      body:
      isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(fontSize: 16),
        ),
      )
          : Column(
        children: [
          // Syncfusion DatePicker
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SfDateRangePicker(
                controller: _datePickerController,
                selectionMode: DateRangePickerSelectionMode.single,
                initialSelectedDate: selectedDate,
                minDate: DateTime.now(),
                maxDate: DateTime.now().add(const Duration(days: 365)),
                onSelectionChanged: (
                    DateRangePickerSelectionChangedArgs args,
                    ) async {
                  if (args.value is DateTime) {
                    setState(() {
                      selectedDate = args.value;
                      _datePickerController.displayDate = args.value;
                    });
                    await fetchSchedule();
                  }
                },
                todayHighlightColor: Colors.transparent,
                selectionColor: AppColors.primaryColor,
                showNavigationArrow: true,
                monthViewSettings:
                const DateRangePickerMonthViewSettings(
                  firstDayOfWeek: 1,
                  viewHeaderHeight: 40,
                  dayFormat: 'EEE',
                ),
                monthCellStyle: const DateRangePickerMonthCellStyle(
                  textStyle: TextStyle(fontSize: 12),
                ),
                headerStyle: const DateRangePickerHeaderStyle(
                  textAlign: TextAlign.center,
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Grid slot
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: GridView.builder(
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 2.4,
                ),
                itemCount: formattedSlots.length,
                itemBuilder: (context, index) {
                  final displaySlot = formattedSlots[index];
                  bool isDisabled = displaySlot.status != 'AVAILABLE';
                  bool isSelected =
                      selectedSlotStartTime == displaySlot.startTime;

                  return GestureDetector(
                    onTap:
                    isDisabled
                        ? null
                        : () {
                      setState(() {
                        if (isSelected) {
                          selectedSlotStartTime = null;
                          selectedSlot = null;
                          countdownTimer?.cancel();
                          remainingSeconds = 0;
                        } else {
                          selectedSlotStartTime =
                              displaySlot.startTime;
                          selectedSlot =
                              displaySlot
                                  .originalSlot; // ⭐ Sử dụng slot gốc
                          startCountdown();
                        }
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                        isDisabled
                            ? Colors.grey.shade400
                            : (isSelected
                            ? Colors.tealAccent
                            : Colors.white),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                          isDisabled
                              ? Colors.grey
                              : (isSelected
                              ? Colors.teal
                              : Colors.grey.shade300),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        displaySlot.displayTime,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          isDisabled
                              ? Colors.grey.shade700
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Countdown
          if (remainingSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
              child: Text(
                "Reservation countdown ${countdownText()}",
                style: const TextStyle(
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFA500),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
            selectedSlot != null && !isCreatingBooking
                ? AppColors.primaryColor
                : Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed:
          (selectedSlot != null && !isCreatingBooking)
              ? showConfirmationDialog
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
            style: TextStyle(fontSize: 16, color: AppColors.whiteColor),
          ),
        ),
      ),
    );
  }
}

// ⭐ THÊM MỚI: Helper class để display slot
class DisplaySlot {
  final String startTime;
  final String endTime;
  final String status;
  final String displayTime;
  final StaffSlot originalSlot; // ⭐ Giữ reference đến slot gốc

  DisplaySlot({
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.displayTime,
    required this.originalSlot,
  });
}

class PhoneNumber {
  final int id;
  final String phoneNumber;
  final bool isPrimary;
  final String formattedPhone;

  PhoneNumber({
    required this.id,
    required this.phoneNumber,
    required this.isPrimary,
    required this.formattedPhone,
  });

  factory PhoneNumber.fromJson(Map<String, dynamic> json) {
    final rawPhone = (json['phoneNumber'] ?? '') as String;
    return PhoneNumber(
      id: json['id'] ?? 0,
      phoneNumber: rawPhone,
      isPrimary: json['primary'] ?? false,
      formattedPhone: _formatPhoneNumber(rawPhone),
    );
  }

  static String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    if (phone.startsWith('1') && phone.length > 10) {
      phone = phone.substring(1);
    }
    if (phone.length <= 3) {
      return '+1 ($phone';
    } else if (phone.length <= 6) {
      return '+1 (${phone.substring(0, 3)}) ${phone.substring(3)}';
    } else {
      return '+1 (${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
    }
  }
}
