import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/view/bokking_screen/user_booking_models.dart';

class CancelledBookingCard extends StatelessWidget {
  final UserBookingList booking;

  const CancelledBookingCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.whiteColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red),
                const SizedBox(width: 16), // Horizontal spacing for separation
                Expanded( // Allow text to take remaining space and wrap if needed
                  child: Text(
                    '${booking.startTime.toLocal().toString().split(' ')[0]} at ${booking.startTime.toLocal().toString().split(' ')[1].substring(0, 5)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (booking.cancelReason != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reason: ${booking.cancelReason}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}