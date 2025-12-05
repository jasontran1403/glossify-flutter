import 'package:flutter/material.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/schedule_state.dart';

import '../../../api/staff_schedule_model.dart';
import '../../../utils/constant/staff_slot.dart';
import '../task_model.dart';

class ScheduleGrid extends StatelessWidget {
  final ScheduleState scheduleState;
  final Function(StaffSlot) onCardTap;
  final Function(StaffSchedule staff, StaffSlot task)? onStaffDropOnCard;
  final bool showStaffSheet;
  final bool showDetailPanel;

  const ScheduleGrid({
    super.key,
    required this.scheduleState,
    required this.onCardTap,
    this.onStaffDropOnCard,
    this.showStaffSheet = false,
    this.showDetailPanel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (scheduleState.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Loading appointments...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Tạo danh sách tất cả appointments
    List<Map<String, dynamic>> allAppointments = [];
    scheduleState.eventsByStaffId.forEach((staffId, tasks) {
      for (var task in tasks) {
        allAppointments.add({'task': task, 'staffId': staffId});
      }
    });

    // Sắp xếp theo thời gian
    allAppointments.sort((a, b) {
      final aTask = a['task'] as Task;
      final bTask = b['task'] as Task;
      final aMinutes = aTask.startTime.hour * 60 + aTask.startTime.minute;
      final bMinutes = bTask.startTime.hour * 60 + bTask.startTime.minute;
      return aMinutes.compareTo(bMinutes);
    });

    if (allAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No appointments for this date',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Tính số cột dựa trên available width
        int crossAxisCount;
        double childAspectRatio;

        if (availableWidth > 1400) {
          crossAxisCount = 5;
          childAspectRatio = 1.3; // ← Tăng từ 0.95 → 1.3
        } else if (availableWidth > 1100) {
          crossAxisCount = 4;
          childAspectRatio = 1.25; // ← Tăng từ 0.9 → 1.25
        } else if (availableWidth > 800) {
          crossAxisCount = 3;
          childAspectRatio = 1.2; // ← Tăng từ 0.85 → 1.2
        } else if (availableWidth > 500) {
          crossAxisCount = 2;
          childAspectRatio = 1.15; // ← Tăng từ 0.8 → 1.15
        } else {
          crossAxisCount = 1;
          childAspectRatio = 1.1; // ← Tăng từ 0.75 → 1.1
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: allAppointments.length,
          itemBuilder: (context, index) {
            final item = allAppointments[index];
            final task = item['task'] as Task;
            final staffId = item['staffId'] as int;

            final staff = scheduleState.staffSchedules.firstWhere(
                  (s) => s.staffId == staffId,
              orElse:
                  () => StaffSchedule(
                staffId: staffId,
                fullName: 'Unknown',
                avatar: "",
                slots: [],
              ),
            );

            return _buildAppointmentCard(
              task,
              staff.fullName,
              context,
              availableWidth,
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(
      Task task,
      String staffName,
      BuildContext context,
      double availableWidth,
      ) {
    final startMinutes = task.startTime.hour * 60 + task.startTime.minute;
    final endMinutes = task.endTime.hour * 60 + task.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    // ═══════════════════════════════════════════════════════════
    // KIỂM TRA CARD CÓ TRONG QUÁ KHỨ KHÔNG
    // ═══════════════════════════════════════════════════════════
    final now = DateTime.now();
    final cardDateTime = DateTime(
      scheduleState.selectedDate.year,
      scheduleState.selectedDate.month,
      scheduleState.selectedDate.day,
      task.startTime.hour,
      task.startTime.minute,
    );
    final isPastAppointment = cardDateTime.isBefore(now);

    // Tính toán responsive scaling
    double fontScale = 1.0;
    double paddingScale = 1.0;
    double iconScale = 1.0;

    if (availableWidth < 600) {
      fontScale = 0.8;
      paddingScale = 0.7;
      iconScale = 0.8;
    } else if (availableWidth < 900) {
      fontScale = 0.9;
      paddingScale = 0.85;
      iconScale = 0.9;
    } else if (availableWidth < 1200) {
      fontScale = 0.95;
      paddingScale = 0.92;
      iconScale = 0.95;
    }

    return DragTarget<StaffSchedule>(
      // ═══════════════════════════════════════════════════════════
      // KHÔNG CHO DRAG VÀO NẾU CARD TRONG QUÁ KHỨ
      // ═══════════════════════════════════════════════════════════
      onWillAccept: (staff) {
        // Nếu appointment trong quá khứ → không accept
        if (isPastAppointment) {
          print('❌ Cannot reassign past appointment at $cardDateTime');
          return false;
        }

        if (staff != null) {
          if (staff.fullName == task.staffName) {
            return false;
          }
        }
        return staff != null;
      },
      // onAccept: (staff) {
      //   if (staff.fullName != task.staffName && onStaffDropOnCard != null) {
      //     onStaffDropOnCard!(staff, task);
      //   }
      // },
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        final staff = candidateData.isNotEmpty ? candidateData.first : null;
        final isDraggingSameStaff = staff != null && staff.fullName == task.staffName;
        final isRejected = rejectedData.isNotEmpty || (isDragOver && isPastAppointment);

        return GestureDetector(
          // onTap: () => onCardTap(task),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              // ═══════════════════════════════════════════════════════════
              // MÀU XÁM NẾU CARD TRONG QUÁ KHỨ
              // ═══════════════════════════════════════════════════════════
              color: isPastAppointment
                  ? Colors.grey.withOpacity(0.3) // Card quá khứ → màu xám
                  : isDraggingSameStaff || isRejected
                  ? Colors.red.withOpacity(0.1)
                  : isDragOver
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPastAppointment
                    ? Colors.grey // Card quá khứ → border xám
                    : isDraggingSameStaff || isRejected
                    ? Colors.red
                    : isDragOver
                    ? Colors.blue
                    : Colors.blue.withOpacity(0.3),
                width: isDragOver || isRejected ? 3.0 : 1.5,
              ),
              boxShadow: isDragOver || isRejected
                  ? [
                BoxShadow(
                  color: (isDraggingSameStaff || isRejected
                      ? Colors.red
                      : Colors.blue)
                      .withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
                  : null,
            ),
            child: Stack(
              children: [
                // Card content
                Padding(
                  padding: EdgeInsets.all(12 * paddingScale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // HEADER: Avatar + Badge
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20 * iconScale,
                            backgroundColor: isPastAppointment
                                ? Colors.grey // Avatar xám nếu quá khứ
                                : Colors.white,
                            child: Text(
                              task.fullName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16 * fontScale,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // ═══════════════════════════════════════════════════════════
                          // ICON KHÓA NẾU CARD TRONG QUÁ KHỨ
                          // ═══════════════════════════════════════════════════════════
                          if (isPastAppointment)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6 * paddingScale,
                                vertical: 3 * paddingScale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock,
                                    color: Colors.white,
                                    size: 11 * iconScale,
                                  ),
                                  SizedBox(width: 3 * paddingScale),
                                  Text(
                                    'Past',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10 * fontScale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isDraggingSameStaff)
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6 * paddingScale,
                                  vertical: 3 * paddingScale,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.block,
                                      color: Colors.white,
                                      size: 11 * iconScale,
                                    ),
                                    SizedBox(width: 3 * paddingScale),
                                    Flexible(
                                      child: Text(
                                        'Same',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10 * fontScale,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (isDragOver && staff != null)
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6 * paddingScale,
                                    vertical: 3 * paddingScale,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '→ ${staff.fullName.split(' ').first}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10 * fontScale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.more_vert,
                                color: Colors.grey[600],
                                size: 22 * iconScale,
                              ),
                        ],
                      ),

                      SizedBox(height: 10 * paddingScale),

                      // CUSTOMER NAME
                      Text(
                        task.fullName,
                        style: TextStyle(
                          fontSize: 16 * fontScale,
                          fontWeight: FontWeight.bold,
                          color: isPastAppointment
                              ? Colors.grey[600] // Text xám nếu quá khứ
                              : Colors.black,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 6 * paddingScale),

                      // TIME
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14 * iconScale,
                            color: isPastAppointment
                                ? Colors.grey[500]
                                : Colors.black87,
                          ),
                          SizedBox(width: 5 * paddingScale),
                          Expanded(
                            child: Text(
                              '${scheduleState.formatTime(task.startTime)} - ${scheduleState.formatTime(task.endTime)}',
                              style: TextStyle(
                                fontSize: 13 * fontScale,
                                color: isPastAppointment
                                    ? Colors.grey[600]
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8 * paddingScale),

                      // STAFF NAME
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * paddingScale,
                          vertical: 4 * paddingScale,
                        ),
                        decoration: BoxDecoration(
                          color: isPastAppointment
                              ? Colors.grey.withOpacity(0.2)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Staff: $staffName',
                          style: TextStyle(
                            fontSize: 12 * fontScale,
                            color: isPastAppointment
                                ? Colors.grey[700]
                                : Colors.black.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(height: 8 * paddingScale),

                      // FOOTER: Services count + Duration
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * paddingScale,
                                vertical: 4 * paddingScale,
                              ),
                              decoration: BoxDecoration(
                                color: isPastAppointment
                                    ? Colors.grey.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${task.taskCount} svc',
                                style: TextStyle(
                                  fontSize: 12 * fontScale,
                                  color: isPastAppointment
                                      ? Colors.grey[700]
                                      : Colors.black.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(width: 8 * paddingScale),
                          Text(
                            '${durationMinutes}m',
                            style: TextStyle(
                              fontSize: 13 * fontScale,
                              color: isPastAppointment
                                  ? Colors.grey[600]
                                  : Colors.black87,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════════════════════════
                // OVERLAY XÁM NẾU CARD TRONG QUÁ KHỨ
                // ═══════════════════════════════════════════════════════════
                if (isPastAppointment)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}