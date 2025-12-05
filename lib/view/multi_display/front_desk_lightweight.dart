import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/view/multi_display/secondary_display_manager.dart';

class FrontDeskLightweight extends StatefulWidget {
  const FrontDeskLightweight({super.key});

  @override
  State<FrontDeskLightweight> createState() => _FrontDeskLightweightState();
}

class _FrontDeskLightweightState extends State<FrontDeskLightweight> {
  Map<String, dynamic>? _currentBooking;
  bool _isInPaymentMode = false;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();

    // Force landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Listen to data từ màn hình chính
    _dataSubscription = SecondaryDisplayService.instance.dataStream.listen(
          (data) {
        _handleDataFromPrimary(data);
      },
    );
  }

  void _handleDataFromPrimary(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    print('📥 FrontDesk received: $type');

    switch (type) {
      case 'BOOKING_TO_PAYMENT':
        if (mounted) {
          setState(() {
            _currentBooking = data['booking'];
            _isInPaymentMode = true;
          });
        }
        break;

      case 'CANCEL_PAYMENT':
        if (mounted) {
          setState(() {
            _currentBooking = null;
            _isInPaymentMode = false;
          });
        }
        break;

      case 'PAYMENT_COMPLETED':
        if (mounted) {
          setState(() {
            _currentBooking = null;
            _isInPaymentMode = false;
          });
        }
        break;
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background tĩnh (thay vì video) để tiết kiệm tài nguyên
          Positioned.fill(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Payment Panel hoặc Welcome Screen
          if (_isInPaymentMode && _currentBooking != null)
            _buildPaymentPanel()
          else
            _buildWelcomeScreen(),

          // Status indicator
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SECONDARY DISPLAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.payment,
            size: 120,
            color: Colors.white70,
          ),
          const SizedBox(height: 24),
          const Text(
            'Customer Display',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for payment...',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentPanel() {
    final bookingId = _currentBooking!['bookingId'] as int;
    final customerName = _currentBooking!['customerName'] as String;
    final amountAfterDiscount = (_currentBooking!['amountAfterDiscount'] as num).toDouble();

    return Center(
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Color(0xFF3B82F6),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment in Progress',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Booking #$bookingId | $customerName',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Amount
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.1),
                    const Color(0xFF3B82F6).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${amountAfterDiscount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Processing indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Please complete payment at the main terminal',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}