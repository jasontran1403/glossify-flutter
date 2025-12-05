import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hair_sallon/view/bokking_screen/user_booking_models.dart';

import 'e_invoice_screen.dart';

class CompletedBookingCard extends StatelessWidget {
  final UserBookingList booking;

  const CompletedBookingCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    String paymentMethodStr = _getPaymentMethodString(booking.paymentMethod);

    return Card(
      color: AppColors.whiteColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          try {
            final detail = await ApiService.getUserBookingDetail(booking.id);
            Navigation.push(context, EInvoiceScreen(detail: detail));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load detail: $e')));
          }
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and time
              Text(
                '${booking.startTime.toLocal().toString().split(' ')[0]} (${booking.startTime.toLocal().toString().split(' ')[1].substring(0, 5)} - ${booking.endTime.toLocal().toString().split(' ')[1].substring(0, 5)})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Staff info
              if (booking.staff != null) ...[
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: booking.staff!.avatar.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: booking.staff!.avatar,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Image.asset(AppImages.user, width: 40, height: 40, fit: BoxFit.cover),
                        errorWidget: (context, url, error) => Image.asset(AppImages.user, width: 40, height: 40, fit: BoxFit.cover),
                      )
                          : Image.asset(AppImages.user, width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(booking.staff!.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Rating: ${booking.staff!.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Services and amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${booking.serviceCount} services'),
                  Text('\$${booking.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              // Payment method
              Row(
                children: [
                  const Icon(Icons.payment, size: 16, color: AppColors.primaryColor),
                  const SizedBox(width: 4),
                  Text(paymentMethodStr),
                ],
              ),
              // Discount and gift card indicators
              if (booking.hasDiscount) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.discount, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    const Text('Discount applied', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ],
              if (booking.hasGiftCard && booking.giftCardAmount != null && booking.giftCardAmount! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('Gift Card: \$${booking.giftCardAmount!.toStringAsFixed(2)}'),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Booking ID
              Row(
                children: [
                  const Icon(Icons.confirmation_number, size: 16, color: AppColors.primaryColor),
                  const SizedBox(width: 4),
                  Text('Booking ID: #${booking.id}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPaymentMethodString(int method) {
    switch (method) {
      case 0:
        return 'Cash';
      case 1:
        return 'Credit Card';
      case 2:
        return 'Cheque';
      default:
        return 'Other';
    }
  }
}