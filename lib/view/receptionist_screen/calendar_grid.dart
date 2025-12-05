import 'package:flutter/material.dart';

class CalendarGrid extends StatelessWidget {
  final int displayHours;
  final int startHour;
  final double hourHeight;

  const CalendarGrid({
    Key? key,
    required this.displayHours,
    required this.startHour,
    required this.hourHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Major lines (every hour)
          ...List.generate(displayHours + 1, (index) {
            return Positioned(
              top: index * hourHeight,
              left: 0,
              right: 0,
              child: Container(height: 2.0, color: Colors.grey[500]!),
            );
          }),
          // 30-min lines
          ...List.generate(2 * displayHours, (index) {
            if (index % 2 != 0) {
              return Positioned(
                top: (index * hourHeight / 2),
                left: 0,
                right: 0,
                child: Container(height: 1.5, color: Colors.grey[400]!),
              );
            }
            return const SizedBox.shrink();
          }),
          // 15-min lines
          ...List.generate(4 * displayHours, (index) {
            if (index % 4 != 0 && index % 2 != 0) {
              return Positioned(
                top: (index * hourHeight / 4),
                left: 0,
                right: 0,
                child: Container(height: 1.0, color: Colors.grey[300]!),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

class TimeLabels extends StatelessWidget {
  final int displayHours;
  final int startHour;
  final double hourHeight;

  const TimeLabels({
    Key? key,
    required this.displayHours,
    required this.startHour,
    required this.hourHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(displayHours, (index) {
        final hour = startHour + index;
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final period = hour < 12 ? 'AM' : 'PM';

        return Positioned(
          top: (index * hourHeight) + 4,
          left: 8,
          child: Text(
            '$displayHour $period',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }),
    );
  }
}