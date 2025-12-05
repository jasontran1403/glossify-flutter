import 'package:flutter/material.dart';
import '../task_model.dart';

class InfoSection extends StatelessWidget {
  final Task task;
  final String appointmentDate;

  const InfoSection({
    super.key,
    required this.task,
    required this.appointmentDate,
  });

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          icon: Icons.person_outline,
          label: 'Customer',
          value: task.fullName,
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: task.phoneNumber ?? '+1 (970) 710-1062',
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          icon: Icons.access_time_outlined,
          label: 'Appointment Time',
          value: appointmentDate,
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          icon: Icons.receipt_outlined,
          label: 'Booking ID',
          value: '#${task.bookingId}',
        ),
        if (task.staffName != null && task.staffName!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Assigned Staff',
            value: task.staffName!,
          ),
        ],
      ],
    );
  }
}