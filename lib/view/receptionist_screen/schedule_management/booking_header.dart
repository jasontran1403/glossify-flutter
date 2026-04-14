import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'booking_state.dart';

class BookingHeader extends StatelessWidget {
  final BookingState scheduleState;
  final bool showStaffSheet;
  final VoidCallback onToggleStaffSheet;
  final VoidCallback onCloseShift;

  const BookingHeader({
    Key? key,
    required this.scheduleState,
    required this.showStaffSheet,
    required this.onToggleStaffSheet,
    required this.onCloseShift,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateLabel = scheduleState.getFormattedDate();

    // ⭐ Get Chicago time for display
    final chicago = tz.getLocation('America/Chicago');
    final chicagoTime = tz.TZDateTime.now(chicago);
    final isDST = chicagoTime.timeZoneOffset.inHours == -5; // CDT (UTC-5) vs CST (UTC-6)
    final tzAbbr = isDST ? 'CDT' : 'CST';
    final timeLabel = '${chicagoTime.hour.toString().padLeft(2, '0')}:${chicagoTime.minute.toString().padLeft(2, '0')}:${chicagoTime.second.toString().padLeft(2, '0')} $tzAbbr';

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

          // Date display with Chicago time
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
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // ⭐ Display Chicago time
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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