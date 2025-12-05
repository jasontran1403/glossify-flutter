import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../api/api_service.dart';
import '../../../api/staff_schedule_model.dart';
import '../../../utils/app_colors/app_colors.dart';
import 'schedule_state.dart';

class BookingDialog {
  static Future<void> show({
    required BuildContext context,
    required StaffSchedule schedule,
    required ScheduleState scheduleState,
  }) async {
    if (scheduleState.selectedServices.isEmpty ||
        scheduleState.selectedTimeForBooking == null) return;

    final int durationMinutes = scheduleState.selectedServices.length * 15;
    final TimeOfDay startTime = TimeOfDay(
      hour: scheduleState.selectedTimeForBooking!.hour,
      minute: scheduleState.selectedTimeForBooking!.minute,
    );

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          TimeOfDay? calculatedEndTime =
          scheduleState.calculateEndTime(startTime, durationMinutes);

          final isAvailable = scheduleState.isTimeSlotAvailable(
            schedule.staffId,
            scheduleState.selectedDate,
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
                          ...scheduleState.selectedServices.map((service) => Padding(
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 20),
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
                                            DateFormat('dd MMM yyyy')
                                                .format(scheduleState.selectedDate),
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
                onPressed: scheduleState.isCreatingBooking
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
                backgroundColor: (!scheduleState.isCreatingBooking && isAvailable)
                ? AppColors.primaryColor
                    : AppColors.porcelainColor,
                shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                ),
                ),
                onPressed: (!scheduleState.isCreatingBooking && isAvailable)
                ? () async {
                scheduleState.isCreatingBooking = true;
                setDialogState(() {});

                String startTimeStr = DateFormat('yyyy-MM-dd HH:mm')
                    .format(scheduleState.selectedTimeForBooking!);

                final res = await ApiService.receptionistCreateBooking(
                staffId: schedule.staffId,
                customerId: 6,
                customerPhone: '10000000000',
                startTime: startTimeStr,
                storeId: scheduleState.storeId,
                serviceIds: scheduleState.selectedServices
                    .map((s) => s.id)
                    .toList(),
                );

                if (!context.mounted) return;

                if (res['success'] == true) {
                await scheduleState.fetchSchedule();

                scheduleState.isCreatingBooking = false;
                scheduleState.selectedServices.clear();
                scheduleState.selectedStaffIdForBooking = null;
                scheduleState.selectedTimeForBooking = null;

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
                } else {
                  scheduleState.isCreatingBooking = false;
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
                  child: scheduleState.isCreatingBooking
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

  static Widget _buildInfoRow(String label, String value) {
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
}