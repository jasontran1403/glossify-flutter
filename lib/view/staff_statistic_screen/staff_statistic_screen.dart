import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/view/bokking_screen/booking_card_shimmer.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

import '../../utils/constant/booking_model.dart';

class StaffStatisticScreen extends StatefulWidget {
  const StaffStatisticScreen({super.key});

  @override
  State createState() => _StaffStatisticScreenState();
}

class _StaffStatisticScreenState extends State<StaffStatisticScreen> {
  bool isLoading = true;

  List<BookingDTO> completedBookings = [];
  String? completedError;

  // Statistic data
  int totalBookings = 0;
  double totalRevenue = 0.0;
  double accumulateTip = 0.0;
  double accumulateShare = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _loadCompletedBookings();
      _calculateStatistics();
    } catch (e) {
      setState(() {
        completedError = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _calculateStatistics() {
    totalBookings = completedBookings.length;
    totalRevenue = completedBookings.fold(0.0, (sum, booking) {
      return sum + (booking.totalPrice);
    });
  }

  Future<void> _loadCompletedBookings() async {
    try {
      final result = await ApiService.getPastBookings();

      setState(() {
        completedBookings = (result['content'] as List<BookingDTO>);
        accumulateTip = result['accumulateTip'];
        accumulateShare = result['accumulateShare'];
        completedError = null;
      });
    } catch (e) {
      setState(() {
        completedError = e.toString();
      });
    }
  }

  Widget _buildStatisticCard() {
    return Card(
      color: AppColors.porcelainColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last 14days statistic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.blackColor,
              ),
            ),
            const SizedBox(height: 16),

            // Booking Count
            Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Booking: $totalBookings times',
                      style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tip
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Tip: \$${accumulateTip.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Share
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Share: \$${accumulateShare.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // Completed bookings list
  Widget _buildCompletedBookings() {
    if (completedError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $completedError',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loadCompletedBookings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (completedBookings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No completed bookings',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: completedBookings.length,
      itemBuilder: (context, index) {
        final booking = completedBookings[index];
        return _buildBookingCard(booking);
      },
    );
  }

  Widget _buildBookingCard(BookingDTO booking) {
    return Card(
      color: AppColors.porcelainColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with date and price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_formatDate(booking.startTime)} - #${booking.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '\$${booking.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Image + details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    AppImages.user,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Service List (mỗi dòng 1 service + price)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: booking.bookingServices.map((bs) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: bs.service.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (bs.service.note != null &&
                                          bs.service.note!.isNotEmpty)
                                        TextSpan(
                                          text: " (${bs.service.note})",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                '\$${bs.service.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 6),

                      // Tip row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tip',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          Text(
                            '\$${(booking.tip).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Payment Method row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payment',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          Text(
                            _mapPaymentMethod(booking.paymentMethod),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _mapPaymentMethod(int method) {
    switch (method) {
      case 0:
        return "PAID";
      case 1:
        return "CASH";
      case 2:
        return "CREDIT";
      default:
        return "UNKNOWN";
    }
  }

  String _formatDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Unknown Date';

      final dateTime = DateTime.parse(dateString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Statistics",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        iconTheme: const IconThemeData(color: AppColors.whiteColor),
      ),
      body: isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (context, index) => const BookingCardShimmer(),
      )
          : RefreshIndicator(
        onRefresh: _loadData, // 👈 gọi lại load
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildStatisticCard(),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Divider(
                  color: AppColors.mistBlueColor,
                  thickness: 1,
                ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  'Completed Bookings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blackColor,
                  ),
                ),
              ),

              _buildCompletedBookings(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
