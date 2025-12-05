import 'package:flutter/material.dart';

import '../calendar_screen/todo_calendar_screen.dart';

class EventCard extends StatelessWidget {
  final Task task;
  final double hourHeight;
  final int startHour;
  final int displayHours;

  const EventCard({
    Key? key,
    required this.task,
    required this.hourHeight,
    required this.startHour,
    required this.displayHours,
  }) : super(key: key);

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'am' : 'pm';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final startMinutes = task.startTime.hour * 60 + task.startTime.minute;
    final endMinutes = task.endTime.hour * 60 + task.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    final top = ((startMinutes / 60.0) - startHour) * hourHeight;
    final height = (durationMinutes / 60.0) * hourHeight;

    if (top < 0 || top + height > displayHours * hourHeight) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height.clamp(12.0, double.infinity),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(
          horizontal: height > 40 ? 12 : 8,
          vertical: height > 40 ? 8 : 4,
        ),
        decoration: BoxDecoration(
          color: task.color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(color: task.color.withOpacity(0.3), width: 0.5),
        ),
        child: _buildContent(durationMinutes, height),
      ),
    );
  }

  Widget _buildContent(int durationMinutes, double cardHeight) {
    if (task.taskCount == 1) {
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.white.withOpacity(0.9), size: 10),
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
}