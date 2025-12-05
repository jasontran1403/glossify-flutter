import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../api/staff_schedule_model.dart';

class DraggableStaffAvatar extends StatelessWidget {
  final StaffSchedule staff;
  final bool isDragging;

  const DraggableStaffAvatar({
    Key? key,
    required this.staff,
    this.isDragging = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDragging ? Colors.blue : Colors.transparent,
          width: 2,
        ),
        boxShadow: isDragging
            ? [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ]
            : null,
      ),
      child:
      CircleAvatar(
        radius: 20, // hoặc dùng iconScale nếu cần responsive
        backgroundColor: Colors.blue[100],
        child: ClipOval(
          child: _buildStaffAvatar(staff, fontScale: 1.0), // có thể truyền scale nếu cần
        ),
      ),
    );
  }

  Widget _buildStaffAvatar(StaffSchedule staff, {double fontScale = 1.0}) {
    final String? avatarUrl = staff.avatar?.trim();
    final bool hasValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http') || avatarUrl.startsWith('https'));

    if (hasValidUrl) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            staff.fullName.isNotEmpty
                ? staff.fullName.trim().substring(0, 1).toUpperCase()
                : '?',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
              fontSize: 16 * fontScale,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildInitialAvatar(staff.fullName, fontScale),
      );
    } else {
      return _buildInitialAvatar(staff.fullName, fontScale);
    }
  }

// Fallback: chữ cái đầu tên trên nền màu
  Widget _buildInitialAvatar(String fullName, double fontScale) {
    final String initial = fullName.isNotEmpty
        ? fullName.trim().split(' ').first.substring(0, 1).toUpperCase()
        : '?';

    return CircleAvatar(
      backgroundColor: Colors.blue[100],
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.blue[800],
          fontWeight: FontWeight.bold,
          fontSize: 16 * fontScale,
        ),
      ),
    );
  }
}