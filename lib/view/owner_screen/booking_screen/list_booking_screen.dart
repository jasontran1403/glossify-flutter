// view/owner_screen/booking_tab.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hair_sallon/view/owner_screen/shimmer_loading.dart';

import '../../../api/api_service.dart';
import '../../../api/checkin_booking_model.dart';

class BookingTab extends StatefulWidget {
  const BookingTab({super.key});

  @override
  State<BookingTab> createState() => _BookingTabState();
}

class _BookingTabState extends State<BookingTab> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<CheckinBookingDTO> _bookingData = [];
  List<CheckinBookingDTO> _filteredBookingData = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _page = 0;
  final int _pageSize = 10;
  final double _loadThreshold = 200.0;
  Timer? _searchDebounce;
  String _lastSearchQuery = '';
  int? _expandedCardIndex;

  @override
  void initState() {
    super.initState();
    _fetchBookingData(isRefresh: true);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _handleLongPress(CheckinBookingDTO booking) {
    _showCheckinConfirmation(booking);
  }

  void _showCheckinConfirmation(CheckinBookingDTO booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Checkin Booking'),
          content: Text('Do you want to checkin for ${booking.customerName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _checkinBooking(booking.id),
              child: const Text('Checkin'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkinBooking(int bookingId) async {
    Navigator.of(context).pop(); // Đóng dialog

    try {
      final response = await ApiService.checkinBooking(bookingId);

      if (mounted) {
        if (response.code == 900) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Checkin successful'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh data sau khi checkin thành công
          _refreshData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Checkin failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final currentQuery = _searchController.text.trim();

    // Nếu query không thay đổi thì không làm gì
    if (currentQuery == _lastSearchQuery) return;

    // Hủy timer cũ nếu có
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }

    // Tạo timer mới với 2 giây debounce
    _searchDebounce = Timer(const Duration(seconds: 2), () {
      _lastSearchQuery = currentQuery;
      _expandedCardIndex = null; // Reset expanded card khi search
      _fetchBookingData(isRefresh: true);
    });
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadThreshold) {
      _fetchBookingData(isRefresh: false);
    }
  }

  Future<void> _fetchBookingData({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _bookingData.clear();
        _filteredBookingData.clear();
        _page = 0;
        _hasMore = true;
      });
    } else if (_isLoadingMore || !_hasMore) {
      return;
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ApiService.searchCheckinBookings(
        searchQuery: _lastSearchQuery,
        page: _page,
        size: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _bookingData = response.bookings;
          _filteredBookingData = response.bookings;
        } else {
          _bookingData.addAll(response.bookings);
          _filteredBookingData.addAll(response.bookings);
        }

        if (response.bookings.length < _pageSize) {
          _hasMore = false;
        }

        _page++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (!isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    // Hủy debounce khi refresh thủ công
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }
    _expandedCardIndex = null; // Reset expanded card khi refresh
    await _fetchBookingData(isRefresh: true);
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatPhoneNumber(String phone) {
    // Format số điện thoại theo chuẩn Mỹ: (XXX) XXX-XXXX
    if (phone.length == 10) {
      return '(${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
    } else if (phone.length == 11 && phone.startsWith('1')) {
      return '+1 (${phone.substring(1, 4)}) ${phone.substring(4, 7)}-${phone.substring(7)}';
    }
    return phone; // Trả về nguyên bản nếu không đúng định dạng
  }

  void _toggleCardExpansion(int index) {
    setState(() {
      if (_expandedCardIndex == index) {
        // Nếu click vào card đang expanded, đóng lại
        _expandedCardIndex = null;
      } else {
        // Nếu click vào card khác, mở card mới và đóng card cũ
        _expandedCardIndex = index;
      }
    });
  }

  Widget _buildServiceList(CheckinBookingDTO booking) {
    // Nhóm các service theo staff name
    final Map<String, List<CheckinBookingServiceDTO>> groupedServices = {};

    for (final service in booking.bookingServices) {
      final staffName = service.staff?.fullName ?? 'No Staff';
      if (!groupedServices.containsKey(staffName)) {
        groupedServices[staffName] = [];
      }
      groupedServices[staffName]!.add(service);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Services:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),

        // Hiển thị các nhóm service theo staff
        ...groupedServices.entries.map((entry) {
          final staffName = entry.key;
          final services = entry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên staff
                Text(
                  'Staff: $staffName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),

                // Các service của staff này
                ...services.map((service) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '• ${service.service?.name ?? 'Unknown Service'}',
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '\$${(service.service?.price ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 8),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar với indicator loading
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Stack(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by customer name or phone...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
              // Hiển thị loading indicator khi đang debounce
              if (_searchDebounce?.isActive ?? false)
                Positioned(
                  right: 8,
                  top: 8,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) => false,
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(), // Hiển thị spinner khi loading
              )
                  : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final booking = _filteredBookingData[index];
                        final startTime = booking.parsedStartTime;
                        final isExpanded = _expandedCardIndex == index;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Card(
                            child: InkWell(
                              onTap: () => _toggleCardExpansion(index),
                              onLongPress: () => _handleLongPress(booking), // THÊM DÒNG NÀY
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left: Customer Avatar
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundImage: NetworkImage(booking.customerAvt),
                                          backgroundColor: Colors.grey.shade200,
                                          child: booking.customerAvt.isEmpty
                                              ? Text(
                                            booking.customerName.isNotEmpty
                                                ? booking.customerName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),

                                        // Center: Customer Information
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Customer name
                                              Text(
                                                booking.customerName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Phone number
                                              Text(
                                                _formatPhoneNumber(booking.customerPhone),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Total amount
                                              Text(
                                                'Total: ${_formatCurrency(booking.totalAmount)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Right: Booking Time
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _formatTime(startTime),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text(
                                              _formatDate(startTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            AnimatedRotation(
                                              duration: const Duration(milliseconds: 300),
                                              turns: isExpanded ? 0.5 : 0,
                                              child: Icon(
                                                Icons.expand_more,
                                                color: Colors.grey,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Animated expanded section for services
                                    AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 300),
                                      crossFadeState: isExpanded
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: _buildServiceList(booking),
                                      secondChild: const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _filteredBookingData.length,
                    ),
                  ),

                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),

                  if (!_hasMore && _filteredBookingData.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No more bookings',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),

                  if (_filteredBookingData.isEmpty && (_searchController.text.isNotEmpty || _lastSearchQuery.isNotEmpty))
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No bookings found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}