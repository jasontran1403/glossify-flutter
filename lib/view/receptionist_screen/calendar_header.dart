import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHeader extends StatelessWidget {
  final DateTime selectedDate;
  final bool isLoading;
  final VoidCallback onTodayTap;
  final VoidCallback onRefresh;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onDatePickerTap;

  const CalendarHeader({
    Key? key,
    required this.selectedDate,
    required this.isLoading,
    required this.onTodayTap,
    required this.onRefresh,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onDatePickerTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isTodaySelected = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    final dateLabel = DateFormat('MMMM EEE dd, yyyy').format(selectedDate);

    return Container(
      padding: const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isLoading ? null : onTodayTap,
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
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            icon: Icon(Icons.refresh, color: isLoading ? Colors.grey : Colors.blue),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : onPreviousDay,
            icon: Icon(Icons.chevron_left, color: isLoading ? Colors.grey : Colors.blue),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isLoading ? null : onDatePickerTap,
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
          IconButton(
            onPressed: isLoading ? null : onNextDay,
            icon: Icon(Icons.chevron_right, color: isLoading ? Colors.grey : Colors.blue),
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