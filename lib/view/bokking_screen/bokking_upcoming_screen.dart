import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/auth_helper.dart';
import 'package:hair_sallon/view/bokking_screen/pending_booking_card.dart';
import 'package:hair_sallon/view/bokking_screen/user_booking_models.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

import '../sign_in/sign_in.dart';
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
  bool _isLoggedIn = false;

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

    // ✅ Check login first, then load bookings
    _checkLoginAndLoadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ UPDATED: Check login status with delay to prevent flickering
  Future<void> _checkLoginAndLoadBookings() async {
    // Add delay to prevent flickering and smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    final isLoggedIn = await AuthHelper.isLoggedIn();

    if (isLoggedIn) {
      // User is logged in, keep loading state and fetch bookings
      setState(() {
        _isLoggedIn = true;
      });
      await _loadBookings();
    } else {
      // User not logged in, stop loading and show login UI
      setState(() {
        _isLoggedIn = false;
        isLoading = false;
      });
    }
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

  // ✅ Show login required UI
  Widget _buildLoginRequiredUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Login Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please sign in to view your bookings',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    // Navigate to SignInScreen
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignInScreen()),
                    );

                    // After returning, check if user logged in
                    if (mounted) {
                      final isLoggedIn = await AuthHelper.isLoggedIn();
                      if (isLoggedIn) {
                        setState(() {
                          _isLoggedIn = true;
                          isLoading = true;
                        });
                        _loadBookings();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Click here to sign in to view your bookings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              height: MediaQuery.of(context).size.height * 0.8,
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
      // ✅ Show shimmer while checking login, then show appropriate content
      body: isLoading
          ? ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) => const BookingCardShimmer(),
      )
          : !_isLoggedIn
          ? _buildLoginRequiredUI()
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