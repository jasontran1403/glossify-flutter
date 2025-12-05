import 'package:flutter/material.dart';
import 'booking_state.dart';

class BookingHeader extends StatelessWidget {
  final BookingState scheduleState;
  final bool showStaffSheet;
  final VoidCallback onToggleStaffSheet;
  final VoidCallback onCloseShift; // ⭐ THÊM

  const BookingHeader({
    Key? key,
    required this.scheduleState,
    required this.showStaffSheet,
    required this.onToggleStaffSheet,
    required this.onCloseShift, // ⭐ THÊM
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateLabel = scheduleState.getFormattedDate();

    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Staff Sheet Toggle Button
          IconButton(
            onPressed: onToggleStaffSheet,
            icon: Icon(
              showStaffSheet ? Icons.people : Icons.people_outline,
              color: showStaffSheet ? Colors.blue : Colors.grey,
            ),
            style: IconButton.styleFrom(
              backgroundColor: showStaffSheet
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 16),

          // ⭐ PREVIOUS DAY BUTTON
          IconButton(
            onPressed: scheduleState.isLoading ? null : scheduleState.previousDay,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),

          // Date display
          Expanded(
            child: GestureDetector(
              onTap: scheduleState.isLoading ? null : () => scheduleState.selectDate(context),
              child: Opacity(
                opacity: scheduleState.isLoading ? 0.5 : 1.0,
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
                      Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
                      const SizedBox(width: 12),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ⭐ NEXT DAY BUTTON
          IconButton(
            onPressed: scheduleState.isLoading ? null : scheduleState.nextDay,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 16),

          // ⭐ CLOSE SHIFT BUTTON
          ElevatedButton.icon(
            onPressed: scheduleState.isLoading ? null : onCloseShift,
            icon: const Icon(Icons.exit_to_app, size: 20),
            label: const Text('End Shift'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}