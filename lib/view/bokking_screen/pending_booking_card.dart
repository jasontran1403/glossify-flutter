import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/bokking_screen/user_booking_models.dart';
import 'package:hair_sallon/view/bokking_screen/widgets/cancel_booking.dart';

class PendingBookingCard extends StatelessWidget {
  final UserBookingList booking;
  final VoidCallback? onCancelSuccess;

  const PendingBookingCard({
    super.key,
    required this.booking,
    this.onCancelSuccess,
  });

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
            // Date and time
            Text(
              '${booking.startTime.toLocal().toString().split(' ')[0]} at ${booking.startTime.toLocal().toString().split(' ')[1].substring(0, 5)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Customer info
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(booking.customerName)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Text(booking.customerPhone),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(booking.location)),
              ],
            ),
            const SizedBox(height: 12),
            // Services summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${booking.serviceCount} services'),
                Text('\$${booking.totalAmount.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 12),
            // Cancel button
            if (booking.canCancel)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigation.push(
                      context,
                      CancelBooking(bookingId: booking.id),
                    );
                    if (result == true && onCancelSuccess != null) {
                      onCancelSuccess!();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}