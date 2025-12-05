import 'package:flutter/material.dart';
import 'schedule_state.dart';

class ScheduleHeader extends StatelessWidget {
  final ScheduleState scheduleState;
  final bool showStaffSheet;
  final VoidCallback onToggleStaffSheet;

  const ScheduleHeader({
    Key? key,
    required this.scheduleState,
    required this.showStaffSheet,
    required this.onToggleStaffSheet,
  }) : super(key: key);

  Future<void> _showDatePicker(BuildContext context) async {
    final today = DateTime.now();
    final maxDate = today.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: scheduleState.selectedDate,
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
    if (picked != null && picked != scheduleState.selectedDate) {
      scheduleState.selectedDate = picked;
      scheduleState.fetchSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = scheduleState.dateFormat.format(scheduleState.selectedDate);

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

          // Date display
          Expanded(
            child: GestureDetector(
              onTap: scheduleState.isLoading ? null : () => _showDatePicker(context),
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
                          fontSize: 16,
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
          const SizedBox(width: 16),

          // Refresh button
          IconButton(
            onPressed: scheduleState.isLoading ? null : scheduleState.fetchSchedule,
            icon: Icon(
              Icons.refresh,
              color: scheduleState.isLoading ? Colors.grey : Colors.blue,
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
}