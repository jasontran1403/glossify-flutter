import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../api/staff_schedule_model.dart';
import '../../../utils/constant/staff_slot.dart';
import '../task_model.dart';
import 'booking_state.dart';

class BookingGrid extends StatelessWidget {
  final BookingState scheduleState;
  final Function(Task) onCardTap;
  final Function(StaffSchedule staff, Task task)? onStaffDropOnCard;
  final bool showStaffSheet;
  final bool showDetailPanel;
  final DateTime selectedDate;
  final Map<int, List<Task>>? filteredEventsByStaffId;

  const BookingGrid({
    super.key,
    required this.scheduleState,
    required this.onCardTap,
    this.onStaffDropOnCard,
    this.showStaffSheet = false,
    this.showDetailPanel = false,
    required this.selectedDate,
    this.filteredEventsByStaffId,
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

    final eventsToShow = filteredEventsByStaffId ?? scheduleState.eventsByStaffId;

    List<Map<String, dynamic>> allAppointments = [];
    eventsToShow.forEach((staffId, tasks) {
      for (var task in tasks) {
        allAppointments.add({'task': task, 'staffId': staffId});
      }
    });

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

        int crossAxisCount;
        double childAspectRatio;

        if (availableWidth > 1400) {
          crossAxisCount = 5;
          childAspectRatio = 1.05;
        } else if (availableWidth > 1100) {
          crossAxisCount = 4;
          childAspectRatio = 1.0;
        } else if (availableWidth > 800) {
          crossAxisCount = 3;
          childAspectRatio = 0.95;
        } else if (availableWidth > 500) {
          crossAxisCount = 2;
          childAspectRatio = 0.9;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 0.85;
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
              orElse: () => StaffSchedule(
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

    final now = DateTime.now();
    final cardDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      task.startTime.hour,
      task.startTime.minute,
    );
    final isPastAppointment = cardDateTime.isBefore(now);

    double fontScale = 1.0;
    double paddingScale = 1;
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

    // ⭐ FIXED: Animation for newly added booking with Key
    return TweenAnimationBuilder<double>(
      key: ValueKey('booking_${task.bookingId}_${task.isNewlyAdded}'), // ⭐ ADD KEY
      duration: task.isNewlyAdded
          ? const Duration(milliseconds: 600)
          : Duration.zero, // ⭐ NO animation for existing bookings
      curve: Curves.elasticOut,
      tween: Tween<double>(
        begin: task.isNewlyAdded ? 0.0 : 1.0,
        end: 1.0,
      ),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: scale.clamp(0.0, 1.0), // ⭐ CLAMP to ensure valid range
            child: child!,
          ),
        );
      },
      child: DragTarget<StaffSchedule>(
        // ... rest of the code stays the same
        onWillAccept: (staff) {
          if (staff == null) return false;
          if (isPastAppointment) return false;
          if (staff.fullName == task.staffName) return false;
          return true;
        },
        onAccept: (staff) {
          if (isPastAppointment) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.lock, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cannot reassign past appointments',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
            return;
          }

          if (staff.fullName == task.staffName) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.block, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cannot reassign to the same staff: ${staff.fullName}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
            return;
          }

          if (onStaffDropOnCard != null) {
            onStaffDropOnCard!(staff, task);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isDragOver = candidateData.isNotEmpty;
          final staff = candidateData.isNotEmpty ? candidateData.first : null;
          final isDraggingSameStaff = staff != null && staff.fullName == task.staffName;
          final isRejected = rejectedData.isNotEmpty ||
              (isDragOver && (isPastAppointment || isDraggingSameStaff));

          // Determine colors based on state
          Color borderColor;
          Color backgroundColor;
          double borderWidth;
          List<BoxShadow> shadows;

          if (isRejected) {
            borderColor = Colors.red;
            backgroundColor = Colors.red.withOpacity(0.1);
            borderWidth = 3.0;
            shadows = [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ];
          } else if (isDragOver) {
            borderColor = Colors.blue;
            backgroundColor = Colors.blue.withOpacity(0.15);
            borderWidth = 3.0;
            shadows = [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ];
          } else if (task.isNewlyAdded) {
            borderColor = Colors.green.shade400;
            backgroundColor = Colors.green.shade50;
            borderWidth = 3.0;
            shadows = [
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ];
          } else {
            borderColor = Colors.grey[300]!;
            backgroundColor = Colors.white;
            borderWidth = 1.5;
            shadows = [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ];
          }

          return GestureDetector(
            onTap: () => onCardTap(task),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
                boxShadow: shadows,
              ),
              child: Stack(
                children: [
                  // ⭐ Pulsing animation for new booking
                  if (task.isNewlyAdded)
                    Positioned.fill(
                      child: _PulsingGlow(
                        color: Colors.green.shade300,
                      ),
                    ),

                  // Main content
                  Padding(
                    padding: EdgeInsets.all(10 * paddingScale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HEADER
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18 * iconScale,
                              backgroundColor: Colors.grey[300],
                              child: ClipOval(
                                child: _buildCustomerAvatar(task, iconScale, fontScale),
                              ),
                            ),
                            SizedBox(width: 8 * paddingScale),
                            Expanded(
                              child: Text(
                                task.fullName,
                                style: TextStyle(
                                  fontSize: 14 * fontScale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4 * paddingScale),

                            // Priority badges
                            if (task.isNewlyAdded)
                              _buildNewBadge(fontScale, paddingScale)
                            else if (isRejected && isDragOver)
                              _buildRejectBadge(fontScale, paddingScale, iconScale)
                            else if (isDragOver && !isRejected && staff != null)
                                _buildDragBadge(staff, fontScale, paddingScale)
                              else
                                _buildStatusBadge(task.status, fontScale, paddingScale),
                          ],
                        ),

                        SizedBox(height: 6 * paddingScale),

                        // TIME
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 13 * iconScale,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4 * paddingScale),
                            Expanded(
                              child: Text(
                                '${scheduleState.formatTime(task.startTime)} - ${scheduleState.formatTime(task.endTime)}',
                                style: TextStyle(
                                  fontSize: 12 * fontScale,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 6 * paddingScale),

                        // SERVICES LIST
                        if (task.serviceItems != null && task.serviceItems!.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(8 * paddingScale),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.list_alt,
                                      size: 12 * iconScale,
                                      color: Colors.blue[700],
                                    ),
                                    SizedBox(width: 4 * paddingScale),
                                    Text(
                                      'Services:',
                                      style: TextStyle(
                                        fontSize: 10 * fontScale,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6 * paddingScale),
                                Container(
                                  height: 120 * paddingScale,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.only(right: 4 * paddingScale),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: _buildServicesByStaff(
                                        task,
                                        fontScale,
                                        paddingScale,
                                        iconScale,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 6 * paddingScale),

                        // FOOTER
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8 * paddingScale,
                                  vertical: 4 * paddingScale,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Text(
                                  '${task.taskCount} svc',
                                  style: TextStyle(
                                    fontSize: 11 * fontScale,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            SizedBox(width: 6 * paddingScale),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8 * paddingScale,
                                  vertical: 4 * paddingScale,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  '${durationMinutes}m',
                                  style: TextStyle(
                                    fontSize: 11 * fontScale,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ⭐ NEW: Build "NEW" badge with animation
  Widget _buildNewBadge(double fontScale, double paddingScale) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      tween: Tween(begin: 0.8, end: 1.2),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8 * paddingScale,
              vertical: 4 * paddingScale,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade600,
                  Colors.green.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fiber_new,
                  color: Colors.white,
                  size: 14 * fontScale,
                ),
                SizedBox(width: 4 * paddingScale),
                Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11 * fontScale,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ⭐ Build reject badge
  Widget _buildRejectBadge(double fontScale, double paddingScale, double iconScale) {
    return Container(
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
            size: 10 * iconScale,
          ),
          SizedBox(width: 2 * paddingScale),
          Text(
            'No',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9 * fontScale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ⭐ Build drag badge
  Widget _buildDragBadge(StaffSchedule staff, double fontScale, double paddingScale) {
    return Container(
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
          fontSize: 9 * fontScale,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Build services by staff (không đổi)
  List<Widget> _buildServicesByStaff(
      Task task,
      double fontScale,
      double paddingScale,
      double iconScale,
      ) {
    if (task.serviceItems == null || task.serviceItems!.isEmpty) {
      return [];
    }

    if (!task.hasMultipleStaffs) {
      return [
        if (task.staffName != null)
          Padding(
            padding: EdgeInsets.only(bottom: 4 * paddingScale),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  size: 10 * iconScale,
                  color: Colors.blue[700],
                ),
                SizedBox(width: 4 * paddingScale),
                Expanded(
                  child: Text(
                    task.staffName!,
                    style: TextStyle(
                      fontSize: 10 * fontScale,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ...task.serviceItems!
            .map((serviceItem) => Padding(
          padding: EdgeInsets.only(bottom: 2 * paddingScale, left: 14 * paddingScale),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6 * paddingScale),
              Expanded(
                child: Text(
                  '${serviceItem.name} - \$${serviceItem.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 9 * fontScale,
                    color: Colors.grey[800],
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ))
            .toList(),
      ];
    } else {
      Map<String, List<ServiceItem>> servicesByStaff = {};

      for (var service in task.serviceItems!) {
        final staffName = service.staffName ?? 'Unknown Staff';
        if (!servicesByStaff.containsKey(staffName)) {
          servicesByStaff[staffName] = [];
        }
        servicesByStaff[staffName]!.add(service);
      }

      List<Widget> widgets = [];
      final staffNames = servicesByStaff.keys.toList();

      for (int i = 0; i < staffNames.length; i++) {
        final staffName = staffNames[i];
        final services = servicesByStaff[staffName]!;

        if (i > 0) {
          widgets.add(SizedBox(height: 6 * paddingScale));
        }

        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 3 * paddingScale),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3 * paddingScale),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 8 * iconScale,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 4 * paddingScale),
                Expanded(
                  child: Text(
                    staffName,
                    style: TextStyle(
                      fontSize: 10 * fontScale,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );

        for (var service in services) {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: 2 * paddingScale, left: 14 * paddingScale),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6 * paddingScale),
                  Expanded(
                    child: Text(
                      '${service.name} - \$${service.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 9 * fontScale,
                        color: Colors.grey[800],
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      return widgets;
    }
  }

  Widget _buildStatusBadge(String status, double fontScale, double paddingScale) {
    final statusColor = _getStatusColor(status);
    final displayText = _getStatusLabel(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * paddingScale,
        vertical: 3 * paddingScale,
      ),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9 * fontScale,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'NEW_BOOKED':
      case 'BOOKED':
        return const Color(0xFF2196F3);
      case 'CHECKED_IN':
        return const Color(0xFF4CAF50);
      case 'IN_PROGRESS':
        return const Color(0xFFFF9800);
      case 'REQUEST_MORE_STAFF':
        return const Color(0xFFFFD54F);
      case 'WAITING_PAYMENT':
        return const Color(0xFF9C27B0);
      case 'PAID':
        return const Color(0xFF009688);
      case 'CANCELED':
        return const Color(0xFFF44336);
      case 'PAST':
        return const Color(0xFF757575);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Widget _buildCustomerAvatar(Task task, double iconScale, double fontScale) {
    final String? avatarUrl = task.customerAvt?.trim();
    final bool hasValidAvatar = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl.startsWith('http');

    if (hasValidAvatar) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => _buildInitialLetterAvatar(task, fontScale),
      );
    } else {
      return _buildInitialLetterAvatar(task, fontScale);
    }
  }

  Widget _buildInitialLetterAvatar(Task task, double fontScale) {
    final String initial = task.fullName.isNotEmpty
        ? task.fullName.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      color: const Color(0xFF3B82F6),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16 * fontScale,
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'NEW_BOOKED':
      case 'BOOKED':
        return 'BOOKED';
      case 'CHECKED_IN':
        return 'CHECKED_IN';
      case 'REQUEST_MORE_STAFF':
        return 'REQUEST_MORE_STAFF';
      case 'IN_PROGRESS':
        return 'IN_PROGRESS';
      case 'WAITING_PAYMENT':
        return 'WAITING_PAYMENT';
      case 'PAID':
        return 'PAID';
      case 'CANCELED':
        return 'CANCELED';
      case 'PAST':
        return 'PAST';
      default:
        return status;
    }
  }
}

// ⭐ NEW: Pulsing glow animation widget
class _PulsingGlow extends StatefulWidget {
  final Color color;

  const _PulsingGlow({required this.color});

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: RadialGradient(
              colors: [
                widget.color.withOpacity(_animation.value),
                Colors.transparent,
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        );
      },
    );
  }
}