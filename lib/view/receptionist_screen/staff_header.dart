import 'package:flutter/material.dart';
import '../../api/staff_schedule_model.dart';

class StaffHeader extends StatelessWidget {
  final List<StaffSchedule> staffSchedules;
  final double staffColumnWidth;
  final double timeColumnWidth;
  final ScrollController scrollController;

  const StaffHeader({
    Key? key,
    required this.staffSchedules,
    required this.staffColumnWidth,
    required this.timeColumnWidth,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: Colors.white,
      child: Row(
        children: [
          // Empty space for time column - QUAN TRỌNG
          SizedBox(width: timeColumnWidth),

          // Scrollable staff names - DÙNG CONTROLLER
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController, // ← PHẢI CÓ DÒNG NÀY
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(), // ← THÊM DÒNG NÀY
              child: Row(
                children: staffSchedules.map((schedule) => Container(
                  width: staffColumnWidth,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Text(
                    schedule.fullName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}