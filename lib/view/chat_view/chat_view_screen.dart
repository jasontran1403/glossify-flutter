import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/chat_view/widget/chat_screen.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constant/booking_model.dart';

class ChatViewScreen extends StatefulWidget {
  const ChatViewScreen({super.key});

  @override
  State<ChatViewScreen> createState() => _ChatViewScreenState();
}

class _ChatViewScreenState extends State<ChatViewScreen> {
  List<BookingDTO> upcomingBookings = [];
  bool _isLoading = true;
  bool _isRoleLoading = true;
  String? _errorMessage;
  int _currentPage = 0;
  final int _pageSize = 4;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  late String _userRole;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserRole();

    if (_userRole == 'STAFF') {
      await _fetchUpcomingBookings();
    } else {
      setState(() {
        _isLoading = false;
        _isRoleLoading = false;
      });
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role') ?? "";
      _isRoleLoading = false;
    });
  }

  Future<void> _fetchUpcomingBookings({int page = 0}) async {
    try {
      setState(() {
        if (page == 0) _isLoading = true;
      });

      final response = await ApiService.getBookings(page: page, size: _pageSize);
      final List<BookingDTO> bookings = response['content'] ?? [];

      setState(() {
        _currentPage = page;
        _hasNextPage = response['hasNextPage'] ?? false;

        if (page == 0) {
          upcomingBookings = bookings;
        } else {
          upcomingBookings.addAll(bookings);
        }

        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _fetchUpcomingBookings(page: _currentPage + 1);
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải thêm: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasNextPage = true;
      upcomingBookings.clear();
      _isLoadingMore = false;
      _errorMessage = null;
    });

    try {
      await _fetchUpcomingBookings(page: 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi refresh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRoleLoading) {
      return Scaffold(
        backgroundColor: AppColors.porcelainColor,
        appBar: ComAppbar(
          bgColor: AppColors.whiteColor,
          title: "Upcoming Booking",
          elevation: 0.0,
          centerTitle: true,
          isTitleBold: true,
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: AppColors.blackColor),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userRole != 'STAFF') {
      return Scaffold(
        backgroundColor: AppColors.porcelainColor,
        appBar: ComAppbar(
          bgColor: AppColors.whiteColor,
          title: "Upcoming Booking",
          elevation: 0.0,
          centerTitle: true,
          isTitleBold: true,
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: AppColors.blackColor),
        ),
        body: const Center(
          child: Text(
            'This feature is only available for staff members',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Upcoming Booking",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: AppColors.blackColor),
      ),
      body: SafeArea(child: _buildBookingList()),
    );
  }

  Widget _buildBookingList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primaryColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_isLoading && upcomingBookings.isEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: buildChatCardShimmer(),
                ),
                childCount: 8,
              ),
            )
          else if (_errorMessage != null && upcomingBookings.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(fontSize: 16, color: Colors.red), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () => _fetchUpcomingBookings(), child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            )
          else if (upcomingBookings.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(
                    child: Text('No upcoming bookings found', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final booking = upcomingBookings[index];
                    final serviceNames = booking.bookingServices.map((s) => s.service.name).join(", ");

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          if (booking.status.toUpperCase() == 'CHECKED_IN' || booking.status.toUpperCase() == 'IN_PROGRESS') {
                            Navigation.push(
                              context,
                              ChatScreen(
                                username: booking.customerName,
                                userphoto: 'assets/images/user2.jpeg',
                                bookingId: booking.id,
                              ),
                            );
                          } else if (booking.status.toUpperCase() == 'BOOKED') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('This booking has not been checked in yet'),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.only(bottom: 680, left: 20, right: 20),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _getStatusBackgroundColor(booking.status),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: AppColors.blackColor.withAlpha(13), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.transparent,
                                  child: ClipOval(
                                    child: Image.asset('assets/images/user2.jpeg', fit: BoxFit.cover, width: 40, height: 40),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(booking.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(booking.status),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(booking.status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      const Text("Services:", style: TextStyle(fontSize: 14, color: Colors.black)),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        width: 200,
                                        child: Text(serviceNames, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey), maxLines: 5, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(DateFormat('HH:mm').format(DateTime.parse(booking.startTime)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text(DateFormat('dd/MM').format(DateTime.parse(booking.startTime)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: upcomingBookings.length,
                ),
              ),

          if (upcomingBookings.isNotEmpty && _hasNextPage)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: _isLoadingMore
                    ? const Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Đang tải thêm...')]))
                    : Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: _loadMoreData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.porcelainColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Load more', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildChatCardShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 100,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: double.infinity, height: 12, color: Colors.white),
              const SizedBox(height: 8),
              Container(width: 150, height: 10, color: Colors.white),
              const SizedBox(height: 8),
              Container(width: 100, height: 10, color: Colors.white),
            ]),
          ),
          const SizedBox(width: 12),
          Container(width: 40, height: 10, color: Colors.white),
        ]),
      ),
    );
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toUpperCase()) {
      case 'BOOKED':
        return Colors.orangeAccent.withOpacity(0.1);
      case 'CHECKED_IN':
        return Colors.teal.withOpacity(0.2);
      default:
        return AppColors.porcelainColor;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'BOOKED':
        return Colors.orange;
      case 'CHECKED_IN':
        return Colors.teal;
      case 'COMPLETED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}