import 'package:flutter/material.dart';
import '../../../utils/constant/staff_slot.dart';
import '../task_model.dart';

class ServiceSection extends StatelessWidget {
  final Task task;

  const ServiceSection({
    super.key,
    required this.task,
  });

  Widget _buildServiceItem(ServiceItem serviceItem) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  serviceItem.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${serviceItem.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDuration() {
    if (task.startTime == null || task.endTime == null) {
      return const SizedBox();
    }

    // SỬA: Tính toán duration từ TimeOfDay
    final startMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
    final endMinutes = task.endTime!.hour * 60 + task.endTime!.minute;
    final totalMinutes = endMinutes - startMinutes;

    if (totalMinutes <= 0) {
      return const SizedBox();
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicePrice() {
    if (task.totalAmount == null || task.totalAmount == 0) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(Icons.attach_money, size: 16, color: Colors.green[600]),
          const SizedBox(width: 4),
          Text(
            '\$${task.totalAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTime() {
    if (task.startTime == null) {
      return const SizedBox();
    }

    final startTimeStr = _formatTimeOfDay(task.startTime!);
    final endTimeStr = task.endTime != null ? _formatTimeOfDay(task.endTime!) : '';

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            endTimeStr.isNotEmpty ? '$startTimeStr - $endTimeStr' : startTimeStr,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SERVICES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        if (task.serviceItems != null && task.serviceItems!.isNotEmpty)
          ...task.serviceItems!.asMap().entries.map((entry) {
            final index = entry.key;
            final serviceItem = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < task.serviceItems!.length - 1 ? 12 : 0),
              child: _buildServiceItem(serviceItem),
            );
          }).toList()
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF6B7280), size: 20),
                SizedBox(width: 12),
                Text('No services available', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        if (task.serviceItems != null && task.serviceItems!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildServiceTime(),
          _buildServiceDuration(),
          _buildServicePrice(),
        ],
      ],
    );
  }
}