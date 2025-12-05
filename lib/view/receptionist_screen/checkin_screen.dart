import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../api/api_service.dart';
import '../../api/checkin_booking_model.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({Key? key}) : super(key: key);

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  String _phoneNumber = '';
  bool _isSearching = false;
  CheckinBookingDTO? _booking;
  final int _page = 0;
  final int _size = 1;

  String _formatPhoneNumber(String digits) {
    if (digits.isEmpty) return '';

    if (digits.startsWith('1') && digits.length == 1) {
      return '';
    }

    if (digits.length > 1) {
      digits = digits.substring(1);
    }

    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    if (digits.length <= 3) {
      return '+1 ($digits';
    } else if (digits.length <= 6) {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
  }

  void _appendDigit(String digit) {
    setState(() {
      _phoneNumber += digit;
      _phoneNumber = _formatPhoneNumber(_phoneNumber.replaceAll(RegExp(r'[^\d]'), ''));
    });
  }

  void _deleteLast() {
    setState(() {
      if (_phoneNumber.isNotEmpty) {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
        _phoneNumber = _formatPhoneNumber(_phoneNumber.replaceAll(RegExp(r'[^\d]'), ''));
      }
    });
  }

  void _clearPhone() {
    setState(() {
      _phoneNumber = '';
      _booking = null;
    });
  }

  Future<void> _searchBooking() async {
    final searchQuery = _phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (searchQuery.isEmpty) {
      _showTopToast('Please enter a phone number', Colors.orange);
      return;
    }

    if (searchQuery.length < 11) {
      _showTopToast('Phone number must have at least 11 characters', Colors.orange);
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await ApiService.receptionistSearchCheckinBookings(
        searchQuery: searchQuery,
        page: _page,
        size: _size,
      );

      final bookings = response.bookings ?? [];
      if (bookings.isNotEmpty) {
        setState(() {
          _booking = bookings.first;
        });
        _showTopToast('Booking found successfully!', Colors.green);
      } else {
        setState(() {
          _booking = null;
        });
        _showTopToast('No booking found for the phone number you entered.', Colors.red);
      }
    } catch (e) {
      setState(() {
        _booking = null;
      });
      _showTopToast('Search error: $e', Colors.red);
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _checkIn() async {
    if (_booking == null) return;

    try {
      final response = await ApiService.receptionistCheckinBooking(_booking!.id);

      // Check based on the actual ApiResponse structure
      // Assuming the response has a 'code' property or similar for success
      if (response.code == 900 || response.code == 200) { // Adjust based on your API
        _showTopToast(response.message ?? 'Check-in successful!', Colors.green);
        setState(() {
          _booking = null;
          _phoneNumber = '';
        });
      } else {
        _showTopToast(response.message ?? 'Check-in failed!', Colors.red);
      }
    } catch (e) {
      _showTopToast('Check-in error: $e', Colors.red);
    }
  }

  void _showTopToast(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(
          bottom: 100.0,
          left: 16,
          right: 16,
        ),
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],

      // ✅ Dùng Stack để đặt nút Back đè lên UI
      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // ✅ NỘI DUNG GỐC (UI Check-in)
          // -------------------------------------------------------------------
          Row(
            children: [
              // Left side: Booking info / shimmer
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _booking == null
                      ? _buildShimmerPlaceholder()
                      : _buildBookingCard(),
                ),
              ),

              // Right side: keypad input
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 100),

                    // Title
                    const Text(
                      'Please enter your phone number',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Phone display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Text(
                        _phoneNumber.isEmpty
                            ? 'Please enter your phone number'
                            : _phoneNumber,
                        style: TextStyle(
                          fontSize: 18,
                          color: _phoneNumber.isEmpty
                              ? Colors.grey
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Keypad
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Row 1
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildKeyButton('1'),
                              _buildKeyButton('2'),
                              _buildKeyButton('3'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Row 2
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildKeyButton('4'),
                              _buildKeyButton('5'),
                              _buildKeyButton('6'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Row 3
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildKeyButton('7'),
                              _buildKeyButton('8'),
                              _buildKeyButton('9'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Row 4
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed: _deleteLast,
                                icon: const Icon(Icons.backspace,
                                    size: 32, color: Colors.grey),
                                iconSize: 48,
                                padding: const EdgeInsets.all(8),
                              ),
                              _buildKeyButton('0'),
                              IconButton(
                                onPressed: _clearPhone,
                                icon: const Icon(Icons.clear,
                                    size: 32, color: Colors.grey),
                                iconSize: 48,
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Search button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSearching ? null : _searchBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                              : const Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // ✅ NÚT BACK — NẰM SÁT TRÁI, ĐÈ LÊN TOÀN UI
          // -------------------------------------------------------------------
          Positioned(
            top: 40,
            left: 40,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String digit) {
    return GestureDetector(
      onTap: () => _appendDigit(digit),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Ready to Check In',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your phone number to find your booking',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard() {
    final booking = _booking!;
    final startTimeDate = DateTime.tryParse(booking.startTime) ?? DateTime.now();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue[50]!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assignment_turned_in,
                      size: 32,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BOOKING CONFIRMED',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ready for Check-in',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Booking Details
              _buildDetailRow(
                icon: Icons.person_outline,
                title: 'Customer',
                value: booking.customerName ?? 'N/A',
              ),

              const SizedBox(height: 16),

              _buildDetailRow(
                icon: Icons.phone_outlined,
                title: 'Phone',
                value: _formatPhoneNumber(booking.customerPhone),
              ),

              const SizedBox(height: 16),

              _buildDetailRow(
                icon: Icons.access_time_outlined,
                title: 'Appointment Time',
                value: DateFormat('EEE, MMM dd, yyyy • hh:mm a').format(startTimeDate),
              ),

              const SizedBox(height: 16),

              _buildDetailRow(
                icon: Icons.confirmation_number_outlined,
                title: 'Booking ID',
                value: '#${booking.id}',
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),

              const SizedBox(height: 32),

              // Services section (if available)
              if (booking.bookingServices.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SERVICES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...booking.bookingServices.map((service) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.blue[500],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  service.service?.name ?? 'Service',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (service.service?.price != null)
                                Text(
                                  '\$${service.service!.price!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ).toList(),
                    const SizedBox(height: 24),
                  ],
                ),

              // Check-in Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checkIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'CHECK IN NOW',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.blue[600],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: valueStyle ?? const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}