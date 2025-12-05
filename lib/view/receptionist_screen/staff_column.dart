import 'package:flutter/material.dart';
import '../../api/staff_schedule_model.dart';
import '../calendar_screen/todo_calendar_screen.dart';
import 'current_time_indicator.dart';
import 'event_card.dart';

class StaffColumn extends StatelessWidget {
  final StaffSchedule schedule;
  final double staffColumnWidth;
  final double hourHeight;
  final int startHour;
  final int displayHours;
  final List<Task> events;
  final DateTime selectedDate;
  final DateTime currentTime;
  final Function(int staffId, DateTime selectedTime) onGridTap;

  const StaffColumn({
    Key? key,
    required this.schedule,
    required this.staffColumnWidth,
    required this.hourHeight,
    required this.startHour,
    required this.displayHours,
    required this.events,
    required this.selectedDate,
    required this.currentTime,
    required this.onGridTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    for (var i = 0; i < events.length; i++) {
      final event = events[i];

      // Tính toán vị trí
      final startMinutes = event.startTime.hour * 60 + event.startTime.minute;
      final endMinutes = event.endTime.hour * 60 + event.endTime.minute;
      final durationMinutes = endMinutes - startMinutes;
      final top = ((startMinutes / 60.0) - startHour) * hourHeight;
      final height = (durationMinutes / 60.0) * hourHeight;
    }

    final sortedEvents = List<Task>.from(events)
      ..sort((a, b) => (a.startTime.hour * 60 + a.startTime.minute)
          .compareTo(b.startTime.hour * 60 + b.startTime.minute));

    return GestureDetector(
      onTapDown: (details) {
        final localPosition = details.localPosition;
        final tappedMinutesFromStart = (localPosition.dy / hourHeight) * 60;
        final hour = startHour + (tappedMinutesFromStart ~/ 60);
        final minute = (tappedMinutesFromStart % 60).round();
        final roundedMinute = ((minute / 15).round() * 15) % 60;
        final adjustedHour = minute >= 45 && roundedMinute == 0 ? hour + 1 : hour;

        if (adjustedHour >= startHour && adjustedHour < startHour + displayHours) {
          final selectedTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            adjustedHour,
            roundedMinute,
          );
          onGridTap(schedule.staffId, selectedTime);
        }
      },
      child: Container(
        width: staffColumnWidth,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.grey[300]!, width: 1)),
        ),
        child: Stack(
          children: [
            ...sortedEvents.map((task) => EventCard(
              task: task,
              hourHeight: hourHeight,
              startHour: startHour,
              displayHours: displayHours,
            )).toList(),
            if (selectedDate.year == currentTime.year &&
                selectedDate.month == currentTime.month &&
                selectedDate.day == currentTime.day)
              CurrentTimeIndicator(
                currentTime: currentTime,
                hourHeight: hourHeight,
                startHour: startHour,
                displayHours: displayHours,
              ),
          ],
        ),
      ),
    );
  }
}