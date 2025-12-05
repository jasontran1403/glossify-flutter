import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/constant/booking.dart'; // Add this for BookingStatus
import 'package:hair_sallon/view/bokking_screen/pending_booking_card.dart';
import 'package:hair_sallon/view/bokking_screen/user_booking_models.dart';
import 'package:hair_sallon/view/bokking_screen/widgets/cancel_booking.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

import 'booking_card_shimmer.dart';
import 'cancelled_booking_card.dart';
import 'completed_booking_card.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;

  // Store bookings for each tab
  List<UserBookingList> pendingBookings = [];
  List<UserBookingList> completedBookings = [];
  List<UserBookingList> cancelledBookings = [];

  // Pagination support
  int pendingPage = 0;
  int completedPage = 0;
  int cancelledPage = 0;
  bool pendingHasNext = false;
  bool completedHasNext = false;
  bool cancelledHasNext = false;

  // Error states
  String? pendingError;
  String? completedError;
  String? cancelledError;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Load initial data
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _loadTabData(_tabController.index);
    }
  }

  Future<void> _loadBookings() async {
    try {
      await Future.wait([
        _loadPendingBookings(),
        _loadCompletedBookings(),
        _loadCancelledBookings(),
      ]);
    } catch (e) {
      // Handle error globally if needed
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTabData(int tabIndex) async {
    try {
      switch (tabIndex) {
        case 0: // Pending
          if (pendingBookings.isEmpty && pendingError == null) {
            await _loadPendingBookings();
          }
          break;
        case 1: // Completed
          if (completedBookings.isEmpty && completedError == null) {
            await _loadCompletedBookings();
          }
          break;
        case 2: // Cancelled
          if (cancelledBookings.isEmpty && cancelledError == null) {
            await _loadCancelledBookings();
          }
          break;
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _refreshPendingAndCancelled() async {
    await Future.wait([
      _loadPendingBookings(loadMore: false),
      _loadCancelledBookings(loadMore: false),
    ]);
  }

  Future<void> _loadPendingBookings({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        pendingBookings.clear();
        pendingPage = 0;
      }
      final result = await ApiService.getUserListBookings(
        status: BookingStatus.BOOKED,
        page: pendingPage,
        size: 10,
      );

      if (mounted) {
        setState(() {
          pendingBookings.addAll(result['content'] as List<UserBookingList>);
          pendingHasNext = result['hasNextPage'] as bool;
          pendingError = null;
          pendingPage++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          pendingError = e.toString();
        });
      }
    }
  }

  Future<void> _loadCompletedBookings({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        completedBookings.clear();
        completedPage = 0;
      }
      final result = await ApiService.getUserListBookings(
        status: BookingStatus.PAID,
        page: completedPage,
        size: 10,
      );

      if (mounted) {
        setState(() {
          completedBookings.addAll(result['content'] as List<UserBookingList>);
          completedHasNext = result['hasNextPage'] as bool;
          completedError = null;
          completedPage++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          completedError = e.toString();
        });
      }
    }
  }

  Future<void> _loadCancelledBookings({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        cancelledBookings.clear();
        cancelledPage = 0;
      }
      final result = await ApiService.getUserListBookings(
        status: BookingStatus.CANCELED,
        page: cancelledPage,
        size: 10,
      );

      if (mounted) {
        setState(() {
          cancelledBookings.addAll(result['content'] as List<UserBookingList>);
          cancelledHasNext = result['hasNextPage'] as bool;
          cancelledError = null;
          cancelledPage++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          cancelledError = e.toString();
        });
      }
    }
  }

  Widget _buildTabContent(List<UserBookingList> bookings, String? error, int tabIndex, bool hasNext) {
    Future<void> _onRefresh() async {
      switch (tabIndex) {
        case 0:
          await _loadPendingBookings(loadMore: false);
          break;
        case 1:
          await _loadCompletedBookings(loadMore: false);
          break;
        case 2:
          await _loadCancelledBookings(loadMore: false);
          break;
      }
    }

    Widget buildScrollableContent() {
      if (error != null) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8, // Ensure height for pull-to-refresh
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $error'),
                    ElevatedButton(
                      onPressed: _onRefresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      if (bookings.isEmpty) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: const Center(child: Text('No bookings found')),
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollEndNotification &&
                scrollNotification.metrics.pixels == scrollNotification.metrics.maxScrollExtent &&
                hasNext) {
              switch (tabIndex) {
                case 0:
                  _loadPendingBookings(loadMore: true);
                  break;
                case 1:
                  _loadCompletedBookings(loadMore: true);
                  break;
                case 2:
                  _loadCancelledBookings(loadMore: true);
                  break;
              }
            }
            return false;
          },
          child: ListView.builder(
            itemCount: hasNext ? bookings.length + 1 : bookings.length,
            itemBuilder: (context, index) {
              if (index == bookings.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final booking = bookings[index];
              return switch (tabIndex) {
                0 => PendingBookingCard(
                  booking: booking,
                  onCancelSuccess: tabIndex == 0 ? _refreshPendingAndCancelled : null,
                ),
                1 => CompletedBookingCard(booking: booking),
                2 => CancelledBookingCard(booking: booking),
                _ => const SizedBox.shrink(),
              };
            },
          ),
        ),
      );
    }

    return buildScrollableContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            alignment: Alignment.center,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: AppColors.blackColor,
              indicatorColor: AppColors.primaryColor,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(text: 'Appointment'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),
        ),
        title: "Bookings",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        iconTheme: const IconThemeData(color: AppColors.whiteColor),
      ),
      body: isLoading
          ? ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) => const BookingCardShimmer(),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(pendingBookings, pendingError, 0, pendingHasNext),
          _buildTabContent(completedBookings, completedError, 1, completedHasNext),
          _buildTabContent(cancelledBookings, cancelledError, 2, cancelledHasNext),
        ],
      ),
    );
  }
}