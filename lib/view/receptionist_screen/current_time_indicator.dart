import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrentTimeIndicator extends StatelessWidget {
  final DateTime currentTime;
  final double hourHeight;
  final int startHour;
  final int displayHours;

  const CurrentTimeIndicator({
    Key? key,
    required this.currentTime,
    required this.hourHeight,
    required this.startHour,
    required this.displayHours,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentHour = currentTime.hour;
    final currentMinute = currentTime.minute;

    if (currentHour < startHour || currentHour >= startHour + displayHours) {
      return const SizedBox.shrink();
    }

    final minutesFromStart = (currentHour - startHour) * 60 + currentMinute;
    final top = (minutesFromStart / 60.0) * hourHeight;

    final timeStr = DateFormat('h:mm:ss a').format(currentTime);

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 2, color: Colors.red),
          ),
        ],
      ),
    );
  }
}